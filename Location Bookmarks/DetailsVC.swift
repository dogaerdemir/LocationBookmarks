import UIKit
import MapKit
import CoreLocation
import CoreData

protocol HandleMapSearch
{
    func dropPinZoomIn(placemark:MKPlacemark)
}

class DetailsVC: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate, UITextFieldDelegate
{
    @IBOutlet weak var mapView: MKMapView!
    
    var selectedPin: MKPlacemark? = nil
    
    var resultSearchController: UISearchController? = nil
    
    @IBOutlet weak var nameText: UITextField!
    @IBOutlet weak var commentText: UITextField!
    
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var locationButton: UIButton!
    @IBOutlet weak var mapTypeButton: UIButton!
    
    var selectedTitle = ""
    var selectedTitleID : UUID?
    
    var locationManager = CLLocationManager()
    var chosenLatitude = Double()
    var chosenLongitude = Double()
    var annotationTitle = ""
    var annotationSubtitle = ""
    var annotationLatitude = Double()
    var annotationLongitude = Double()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
    
        let locationSearchTable = storyboard!.instantiateViewController(withIdentifier: "LocationSearchTable") as! LocationSearchTable
        resultSearchController = UISearchController(searchResultsController: locationSearchTable)
        resultSearchController?.searchResultsUpdater = locationSearchTable
        
        locationSearchTable.handleMapSearchDelegate = self
        
        let searchBar = resultSearchController!.searchBar
        searchBar.sizeToFit()
        searchBar.placeholder = "Search for places"
        navigationItem.titleView = resultSearchController?.searchBar
        
        resultSearchController?.hidesNavigationBarDuringPresentation = false
        resultSearchController?.dimsBackgroundDuringPresentation = true
        definesPresentationContext = true
        
        locationSearchTable.mapView = mapView
        
        
        setupTextFields()
        mapView.delegate = self
        nameText.delegate = self
        commentText.delegate = self
        
        // Location manager genel olarak bu i??lerden sorumlu
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest // Spesifik konum tespiti (se??enekler aras??nda yakla????k konum da var)
        locationManager.requestWhenInUseAuthorization() // "Uygulamay?? kullan??rken" se??ene??i (arkaplanda aktif se??ene??i de var)
        locationManager.startUpdatingLocation()
        
        let keyboardGesRec = UITapGestureRecognizer(target: self, action: #selector(klavyeyikapat))
        view.addGestureRecognizer(keyboardGesRec)
        
        if(selectedTitle != "") // Tableviewdan geliniyor, kaydedilmi?? haz??r veri
        {
            saveButton.isHidden = true
            locationButton.isHidden = true
            nameText.isUserInteractionEnabled = false
            commentText.isUserInteractionEnabled = false
            mapView.gestureRecognizers?.removeAll()
            searchBar.isHidden = true
            commentText.placeholder = ""
            
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let context = appDelegate.persistentContainer.viewContext
            
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Places")
            let stringUUID = selectedTitleID!.uuidString
            
            fetchRequest.predicate = NSPredicate(format: "id = %@", stringUUID) //id'ye g??re filtreleme
            fetchRequest.returnsObjectsAsFaults = false
            
            do
            {
                let results = try context.fetch(fetchRequest)
                
                if results.count > 0
                {
                    for result in results as! [NSManagedObject]
                    {
                        if let title = result.value(forKey: "title") as? String
                        {
                            annotationTitle = title
                        }
                        
                        if let subtitle = result.value(forKey: "subtitle") as? String
                        {
                            annotationSubtitle = subtitle
                        }
                        
                        if let latitude = result.value(forKey: "latitude") as? Double
                        {
                            annotationLatitude = latitude
                        }
                        
                        if let longitude = result.value(forKey: "longitude") as? Double
                        {
                            annotationLongitude = longitude
                        }
                        
                        // Veritaban??ndan fetch etti??imiz bilgilerle yeni annotation olu??turulacak ve mapte ona g??re g??sterilecek (konumu ve bilgileri)
                        let annotation = MKPointAnnotation()
                        annotation.title = annotationTitle
                        annotation.subtitle = annotationSubtitle
                        let coordinate = CLLocationCoordinate2D(latitude: annotationLatitude, longitude: annotationLongitude)
                        annotation.coordinate = coordinate
                        
                        mapView.addAnnotation(annotation)
                        nameText.text = annotationTitle
                        commentText.text = annotationSubtitle
                        
                        locationManager.stopUpdatingLocation() // Bu ekranda konumun ve haritan??n g??ncellenmemesi laz??m. Statik konum g??sterilecek.
                
                        let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        let region = MKCoordinateRegion(center: coordinate, span: span)
                        
                        mapView.setRegion(region, animated: true)
                    }
                }
            }
            catch
            {
                
            }
        }
        
        else
        {
            // Uzun bas??lmay?? alg??layan gesture recognizer
            let gesRec = UILongPressGestureRecognizer(target: self, action: #selector(chooseLocationPin(gesRec:)))
            gesRec.minimumPressDuration = 0.75 // Ka?? saniye bas??lmas?? gerekiyor
            mapView.addGestureRecognizer(gesRec)
            
            saveButton.isHidden = false
            locationButton.isHidden = false
            searchBar.isHidden = false
            
            nameText.isUserInteractionEnabled = true
            commentText.isUserInteractionEnabled = true
        }
    }
    
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation])
    {
        if selectedTitle == ""
        {
            // Zoom yapacak. Nereye oldu??unu belirledik (burada g??ncel konuma)
            let location = CLLocationCoordinate2D(latitude: locations[0].coordinate.latitude, longitude: locations[0].coordinate.longitude)
            // Zoom seviyesi. Ne kadar k??????kse o kadar zoom yap??yor
            let span = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            // ????lemleri birle??tir. Nereye gidilecek ve ne kadar zoom yap??lacak.
            let region = MKCoordinateRegion(center: location, span: span)
            
            locationManager.stopUpdatingLocation()
            
            mapView.setRegion(region, animated: true) // Birle??tirilen son durumda haritay?? ba??lat
        }
        
    }
    
    @objc func chooseLocationPin(gesRec:UILongPressGestureRecognizer)
    { // Inputu bu fonksiyondan eri??ebilmek i??in ald??k
        if gesRec.state == .began
        {
            let touchedPoint = gesRec.location(in: self.mapView)
            let touchedCoordinates = self.mapView.convert(touchedPoint, toCoordinateFrom: self.mapView) // T??klan??lan noktay?? koordinatlara ??evir
            
            chosenLatitude = touchedCoordinates.latitude
            chosenLongitude = touchedCoordinates.longitude
            
            let annotation = MKPointAnnotation() // Pinleme
            annotation.coordinate = touchedCoordinates // Pin koordinatlar??
            annotation.title = nameText.text // Pin ba??l??????
            annotation.subtitle = commentText.text // Pin a????klama/altba??l??????
            
            mapView.removeAnnotations(mapView.annotations)
            self.mapView.addAnnotation(annotation)
        }
    }
    
    // Pin(ya da annotation) ??zelle??tirme fonksiyonu. Baloncuk eklenmesi bu ??ekilde yap??l??yor s??f??rdan editlenerek.
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView?
    {
        if annotation is MKUserLocation
        {
            return nil
        }
        
        let reuseId = "myAnnotation"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView
        
        if pinView == nil
        {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView?.canShowCallout = true
            pinView?.tintColor = UIColor.red
            
            let button = UIButton(type: UIButton.ButtonType.detailDisclosure) // Bizim info butonu
            pinView?.rightCalloutAccessoryView = button
        }
        
        else
        {
            pinView?.annotation = annotation
        }
        
        return pinView
    }
    
    // Pin'e t??klad??????m??zda ????kan kutucu??a t??kland??????n?? alg??layan fonksiyon. Burada navigasyon ba??lat??lacak.
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl)
    {
        if selectedTitle != ""
        {
            let requestLocation = CLLocation(latitude: annotationLatitude, longitude: annotationLongitude)
            
            CLGeocoder().reverseGeocodeLocation(requestLocation) { placeMarks, error in
                
                if let placemark = placeMarks
                {
                    if placemark.count > 0
                    {
                        let newPlacemark = MKPlacemark(placemark: placemark[0])
                        let item = MKMapItem(placemark: newPlacemark)
                        item.name = self.annotationTitle
                        let launchOption = [MKLaunchOptionsDirectionsModeKey:MKLaunchOptionsDirectionsModeDriving]
                        item.openInMaps(launchOptions: launchOption)
                    }
                }
            }
        }
    }

    @IBAction func saveButton(_ sender: Any)
    {
        
        if nameText.text == ""
        {
            let alert = UIAlertController(title: "Title is required", message: "", preferredStyle: UIAlertController.Style.alert)
            let okButton = UIAlertAction(title: "OK", style: UIAlertAction.Style.cancel){ UIAlertAction in
                alert.dismiss(animated: true, completion: nil)
            }
            
            alert.addAction(okButton)
            self.present(alert, animated: true, completion: nil)
        }
        
        else
        {
            // ---COREDATE KAYDETME---
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let context = appDelegate.persistentContainer.viewContext
            
            
            let newPlace = NSEntityDescription.insertNewObject(forEntityName: "Places", into: context)
            newPlace.setValue(nameText.text, forKey: "title")
            newPlace.setValue(commentText.text, forKey: "subtitle")
            newPlace.setValue(chosenLatitude, forKey: "latitude")
            newPlace.setValue(chosenLongitude, forKey: "longitude")
            newPlace.setValue(UUID(), forKey: "id")
            
            do
            {
                try context.save()
            }
            catch
            {
                
            }
            
            // ---COREDATA KAYDETME---
            
            // Notification center uygulama i??erisinde mesaj/duyuru g??nderiyor. Ba??lang???? VC'de bu mesaj al??nacak ve al??nd??????nda tablo g??ncellenecek
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "newPlace"), object: nil)
            navigationController?.popViewController(animated: true)
        }
    }
    
    @objc func klavyeyikapat()
    {
        view.endEditing(true)
    }
    
    @IBAction func findLocationButton(_ sender: Any)
    {
        locationManager.startUpdatingLocation()
    }
    
    @IBAction func mapTypeButtonClicked(_ sender: Any)
    {
        let alert = UIAlertController(title: "Harita Tipi", message: "", preferredStyle: UIAlertController.Style.actionSheet)
        let hybridType = UIAlertAction(title: "Hybrid", style: UIAlertAction.Style.default){ UIAlertAction in
            self.mapView.mapType = .hybrid
        }
        
        let satelliteType = UIAlertAction(title: "Satellite", style: UIAlertAction.Style.default){ UIAlertAction in
            self.mapView.mapType = .satellite
        }
        
        let standardType = UIAlertAction(title: "Standard", style: UIAlertAction.Style.default){ UIAlertAction in
            self.mapView.mapType = .standard
        }
        
        let dismiss = UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel){ UIAlertAction in
            alert.dismiss(animated: true, completion: nil)
        }
        
        alert.addAction(hybridType)
        alert.addAction(satelliteType)
        alert.addAction(standardType)
        alert.addAction(dismiss)
        self.present(alert, animated: true, completion: nil)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField
        {
            case nameText:
                commentText.becomeFirstResponder()
            default:
                textField.resignFirstResponder()
            }
            return false
      }
    
    func setupTextFields()
    {
        let toolbar = UIToolbar()
        
        let space = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneButtonClicked))
        
        toolbar.setItems([space, done], animated: true)
        toolbar.sizeToFit()
        
        nameText.inputAccessoryView = toolbar
        commentText.inputAccessoryView = toolbar
    }
        
    @objc func doneButtonClicked()
    {
        view.endEditing(true)
    }
}


extension DetailsVC: HandleMapSearch
{
    func dropPinZoomIn(placemark:MKPlacemark)
    {
        selectedPin = placemark
        
        self.mapView.removeAnnotations(mapView.annotations)
        let annotation = MKPointAnnotation()
        annotation.coordinate = placemark.coordinate

        /*
	Pin eklenmesi i??in yorum sat??r?? kald??r??lmal??
        

        annotation.title = placemark.name
        if let city = placemark.locality,
        let state = placemark.administrativeArea {
            annotation.subtitle = "(city) (state)"
        }
        mapView.addAnnotation(annotation)
         
        */

        let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        let region = MKCoordinateRegion(center: placemark.coordinate, span: span)
        mapView.setRegion(region, animated: true)
    }
}
