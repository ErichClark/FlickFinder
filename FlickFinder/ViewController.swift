//
//  ViewController.swift
//  FlickFinder
//
//  Created by Jarrod Parkes on 11/5/15.
//  Copyright © 2015 Udacity. All rights reserved.
//

import UIKit
import Foundation

// MARK: - ViewController: UIViewController

class ViewController: UIViewController {
    
    // MARK: Properties
    
    var keyboardOnScreen = false
    
    // MARK: Outlets
    
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var photoTitleLabel: UILabel!
    @IBOutlet weak var phraseTextField: UITextField!
    @IBOutlet weak var phraseSearchButton: UIButton!
    @IBOutlet weak var latitudeTextField: UITextField!
    @IBOutlet weak var longitudeTextField: UITextField!
    @IBOutlet weak var latLonSearchButton: UIButton!
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        phraseTextField.delegate = self
        latitudeTextField.delegate = self
        longitudeTextField.delegate = self
        subscribeToKeyboardNotifications()
    }
    
    func subscribeToKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: .UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: .UIKeyboardWillHide, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: .UIKeyboardDidShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: .UIKeyboardDidHide, object: nil)
    }
    
    func unsubscribeFromKeyboardNotifications() {
        NotificationCenter.default.removeObserver(self, name: .UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: .UIKeyboardWillHide, object: nil)
        NotificationCenter.default.removeObserver(self, name: .UIKeyboardDidShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: .UIKeyboardDidHide, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unsubscribeFromAllNotifications()
    }
    
    // MARK: Default Parameters
    
    var queryParameters =
        [URLQueryItem(name: Constants.FlickrParameterKeys.APIKey, value: Constants.FlickrParameterValues.APIKey),
         URLQueryItem(name: Constants.FlickrParameterKeys.Extras, value: Constants.FlickrParameterValues.MediumURL),
         URLQueryItem(name: Constants.FlickrParameterKeys.Format, value: Constants.FlickrParameterValues.ResponseFormat),
         URLQueryItem(name: Constants.FlickrParameterKeys.NoJSONCallback, value: Constants.FlickrParameterValues.DisableJSONCallback),
         URLQueryItem(name: Constants.FlickrParameterKeys.SafeSearch, value: Constants.FlickrParameterValues.UseSafeSearch)]
    
    // MARK: Search Actions
    
    @IBAction func searchByPhrase(_ sender: AnyObject) {
        
        userDidTapView(self)
        setUIEnabled(false)
        
        if !phraseTextField.text!.isEmpty {
            photoTitleLabel.text = "Searching..."
            // TODO: Set necessary parameters!
            
            var components = URLComponents()
            components.scheme = Constants.Flickr.APIScheme
            components.host = Constants.Flickr.APIHost
            components.path = Constants.Flickr.APIPath
            components.queryItems = [URLQueryItem]()
            
            queryParameters.append(URLQueryItem(name: Constants.FlickrParameterKeys.Method, value: Constants.FlickrParameterValues.SearchMethod))
            queryParameters.append(URLQueryItem(name: Constants.FlickrParameterKeys.Text, value: phraseTextField.text))
            
            for queryItem in queryParameters {
                components.queryItems!.append(queryItem)
            }
            
            print(components.url!)
            // pageSearch must always be nil here
            displayImageFromFlickrBySearch(components, pageSearch: nil)
            
        } else {
            setUIEnabled(true)
            photoTitleLabel.text = "Phrase Empty."
        }
    }
    
    @IBAction func searchByLatLon(_ sender: AnyObject) {
        
        userDidTapView(self)
        setUIEnabled(false)
        
        if isTextFieldValid(latitudeTextField, forRange: Constants.Flickr.SearchLatRange) && isTextFieldValid(longitudeTextField, forRange: Constants.Flickr.SearchLonRange) {
            photoTitleLabel.text = "Searching..."
            
            // Set Parameters
            
            var components = URLComponents()
            components.scheme = Constants.Flickr.APIScheme
            components.host = Constants.Flickr.APIHost
            components.path = Constants.Flickr.APIPath
            components.queryItems = [URLQueryItem]()
            
            queryParameters.append(URLQueryItem(name: Constants.FlickrParameterKeys.Method, value: Constants.FlickrParameterValues.LAtLonPhotosMethod))
            queryParameters.append(URLQueryItem(name: Constants.FlickrParameterKeys.BoundingBox, value: bboxString()))
            
            for queryItem in queryParameters {
                components.queryItems!.append(queryItem)
            }
            
            print(components.url!)
            // pageSearch must always be nil here
            displayImageFromFlickrBySearch(components, pageSearch: nil)
        } else {
            setUIEnabled(true)
            photoTitleLabel.text = "Lat should be [-90, 90].\nLon should be [-180, 180]."
        }
    }
    
    private func bboxString() -> String {
        if let latitude = Double(latitudeTextField.text!),
            let longitude = Double(longitudeTextField.text!) {
            
            let boxWidth = Constants.Flickr.SearchBBoxHalfWidth
            let boxHeight = Constants.Flickr.SearchBBoxHalfHeight
            let lonUpperLimit = Constants.Flickr.SearchLonRange.1
            let lonLowerLimit = Constants.Flickr.SearchLonRange.0
            let latUpperLimit = Constants.Flickr.SearchLatRange.1
            let latLowerLimit = Constants.Flickr.SearchLatRange.0
            
            let minLongitude = max(longitude - boxWidth, lonLowerLimit)
            let minLatitude = max(latitude - boxHeight, latLowerLimit)
            let maxLongitude = min(longitude + boxWidth, lonUpperLimit)
            let maxLatitude = min(latitude + boxHeight, latUpperLimit)
            
            print("bbox function has been called.")
            return "\(minLongitude),\(minLatitude),\(maxLongitude),\(maxLatitude)"
        } else {
            return "0,0,0,0"
        }
    }
    
    // MARK: JSON Decoder Function
    // Needs to be external or do/try/catch will not share result
    func makeFlickrStructFromJSON(data: Data) -> FlickrJSONstruct? {
        do {
            let jsonDecoder = JSONDecoder()
            let decodedPhotos = try jsonDecoder.decode(FlickrJSONstruct.self, from: data)
            return decodedPhotos
        } catch {
            print(error)
        }
        return nil
    }
    
    // MARK: Flickr API
    private func displayImageFromFlickrBySearch(_ components: URLComponents, pageSearch: Int?) {
        let session = URLSession.shared
        var request = components.url!
        
        // Append a page query to the components URL, if available
        if pageSearch != nil {
            let pageInt: Int = pageSearch!
            let page = URLQueryItem(name: Constants.FlickrParameterKeys.Page, value: String(pageInt))
            var newSearch = components
            newSearch.queryItems!.append(page)
            request = newSearch.url!
        }
        
        // MARK: create network request
        let task = session.dataTask(with: request) { (data, response, error) in
            guard let data = data else {
                print(error as Any)
                return
            }
            
            // MARK: Deserialize JSON
            guard let returnedPhotoStruct = self.makeFlickrStructFromJSON(data: data) else {
                print("Could not make struct from JSON")
                return
            }
            
            // GUARD: fail stat
            guard returnedPhotoStruct.stat != "fail" else {
                self.displayError(error: "No results returned")
                return
            }
            
            // MARK: random page number
            // If no page has been previously selected,
            // chooses a random page and recursively runs itself.
            if pageSearch == nil {
                let possiblePages: Int = returnedPhotoStruct.photos!.pages
                print("possible pages = \(possiblePages)")
                let randomPage = Int(arc4random_uniform(UInt32(possiblePages)))
                
                self.displayImageFromFlickrBySearch(components, pageSearch: randomPage)
            }
            
            // MARK: random photo
            var randomPhotoIndex = 0
            if let perpage = (returnedPhotoStruct.photos?.photo.count) {
                randomPhotoIndex = Int(arc4random_uniform(UInt32(perpage)))
            }
            let photo = returnedPhotoStruct.photos?.photo[randomPhotoIndex]
            let photoTitle = photo?.title ?? "(Untitled)"
            
            // MARK: request for image by URL
            guard let imageURL = photo?.url_m else {
                print("No URL found- running new query")
                self.displayImageFromFlickrBySearch(components, pageSearch: pageSearch)
                return
            }
            if let imageData = try? Data(contentsOf: imageURL) {
                if pageSearch != nil {
                    performUIUpdatesOnMain {
                        self.setUIEnabled(true)
                        self.photoImageView.image = UIImage(data: imageData)
                        self.photoTitleLabel.text = photoTitle
                        print("displaying image \(randomPhotoIndex) on page \(String(describing: returnedPhotoStruct.photos?.page)))")
                    }
                }
            } else {
                self.displayError(error: "Image does not exist at \(String(describing: imageURL))")
            }
            
        }
        task.resume()
    }
}

// MARK: - ViewController: UITextFieldDelegate

extension ViewController: UITextFieldDelegate {
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: Show/Hide Keyboard
    
    @objc func keyboardWillShow(_ notification: Notification) {
        if !keyboardOnScreen {
            view.frame.origin.y -= keyboardHeight(notification)
        }
    }
    
    @objc func keyboardWillHide(_ notification: Notification) {
        if keyboardOnScreen {
            view.frame.origin.y += keyboardHeight(notification)
        }
    }
    
    @objc func keyboardDidShow(_ notification: Notification) {
        keyboardOnScreen = true
    }
    
    @objc func keyboardDidHide(_ notification: Notification) {
        keyboardOnScreen = false
    }
    
    func keyboardHeight(_ notification: Notification) -> CGFloat {
        let userInfo = (notification as NSNotification).userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue
        return keyboardSize.cgRectValue.height
    }
    
    func resignIfFirstResponder(_ textField: UITextField) {
        if textField.isFirstResponder {
            textField.resignFirstResponder()
        }
    }
    
    @IBAction func userDidTapView(_ sender: AnyObject) {
        resignIfFirstResponder(phraseTextField)
        resignIfFirstResponder(latitudeTextField)
        resignIfFirstResponder(longitudeTextField)
    }
    
    // MARK: TextField Validation
    
    func isTextFieldValid(_ textField: UITextField, forRange: (Double, Double)) -> Bool {
        if let value = Double(textField.text!), !textField.text!.isEmpty {
            return isValueInRange(value, min: forRange.0, max: forRange.1)
        } else {
            return false
        }
    }
    
    func isValueInRange(_ value: Double, min: Double, max: Double) -> Bool {
        return !(value < min || value > max)
    }
    
    // if an error occurs, print it and re-enable the UI
    func displayError(error: String) {
        print(error)
        performUIUpdatesOnMain {
            self.setUIEnabled(true)
            self.photoTitleLabel.text = "No photo returned. Try again."
            self.photoImageView.image = nil
        }
    }
}

// MARK: - ViewController (Configure UI)

private extension ViewController {
    
    func setUIEnabled(_ enabled: Bool) {
        photoTitleLabel.isEnabled = enabled
        phraseTextField.isEnabled = enabled
        latitudeTextField.isEnabled = enabled
        longitudeTextField.isEnabled = enabled
        phraseSearchButton.isEnabled = enabled
        latLonSearchButton.isEnabled = enabled
        
        // adjust search button alphas
        if enabled {
            phraseSearchButton.alpha = 1.0
            latLonSearchButton.alpha = 1.0
        } else {
            phraseSearchButton.alpha = 0.5
            latLonSearchButton.alpha = 0.5
        }
    }
}

// MARK: - ViewController (Notifications)

private extension ViewController {
    
    func subscribeToNotification(_ notification: NSNotification.Name, selector: Selector) {
        NotificationCenter.default.addObserver(self, selector: selector, name: notification, object: nil)
    }
    
    func unsubscribeFromAllNotifications() {
        NotificationCenter.default.removeObserver(self)
        unsubscribeFromKeyboardNotifications()
    }
}
