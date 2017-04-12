//
//  ViewController.swift
//  faceCompare
//
//  Created by Wayne Wang on 2017-04-08.
//  Copyright © 2017 Wayne Wang. All rights reserved.
//

import UIKit
import Alamofire
import AlamofireImage
import ImageIO
import SwiftyJSON

class ViewController: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate {

    @IBOutlet weak var result: UILabel!
    
    @IBOutlet weak var userImage: UIImageView!
    
    @IBOutlet weak var returnImage: UIImageView!
    
    var sampleImage : UIImage = UIImage(named: "sample")!
    
    let imagePicker = UIImagePickerController()
    
    var context: CIContext = CIContext(options: nil)
    
    let headers: HTTPHeaders = [
        "Content-Type": "application/json",
        "Ocp-Apim-Subscription-Key" : "50dc615efac4464282acc496329ebe85"
    ]
    @IBOutlet weak var upload: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.userImage.image = sampleImage
        self.returnImage.image = sampleImage
        self.imagePicker.delegate = self
        self.view.backgroundColor = UIColor(patternImage: UIImage(named: "background.png")!)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func uploadPhoto(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
        imagePicker.mediaTypes = UIImagePickerController.availableMediaTypes(for: .photoLibrary)!
        imagePicker.modalPresentationStyle = .popover
        present(imagePicker, animated: true, completion: nil)
        imagePicker.popoverPresentationController?.sourceView = userImage
    }
    
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let chosenImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            userImage.contentMode = .scaleAspectFit
            sampleImage = chosenImage
            for view in self.userImage.subviews {
                view.removeFromSuperview()
            }
            self.userImage.image = sampleImage
            uploadImageToServer()
        }else{
            let ac = UIAlertController(title: "Error", message: "Cannot choose!", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
        }
        dismiss(animated:true, completion: nil)
        
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    // 1
    func uploadImageToServer(){
        
        Alamofire.upload(multipartFormData: { multipartFormData in
            
            if let imageData = UIImageJPEGRepresentation(self.sampleImage, 0.3) {
                multipartFormData.append(imageData, withName: "file",fileName: self.generateRandomStringWithLength(length: 6), mimeType: "image/jpeg")
            }
            else if let imageData = UIImagePNGRepresentation(self.sampleImage){
                multipartFormData.append(imageData, withName: "file",fileName: "myPhoto.png", mimeType: "image/png")
            }

        },
            to:"http://faceurl.azurewebsites.net/Image/ProcessRequest2")
        { (result) in
            switch result {
            case .success(let upload, _, _):
                
                upload.uploadProgress(closure: { (progress) in
                    let alert = UIAlertController(title: nil, message: "Please wait...", preferredStyle: .alert)
                    let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
                    loadingIndicator.hidesWhenStopped = true
                    loadingIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.gray
                    loadingIndicator.startAnimating();
                    alert.view.addSubview(loadingIndicator)
                    self.present(alert, animated: true, completion: nil)
                    print("Upload Progress: \(progress.fractionCompleted)")
                    
                })
                
                upload.responseJSON { response in
                    if let jsonRes = response.result.value {
                        let json = JSON(jsonRes)
                        let url = json["imageUrl"].stringValue
                        self.sendRequest(url : url)
                    }
                    
                    
                    //print(response.result.value as Any)
                }
                
            case .failure(let encodingError):
                self.dismiss(animated: true, completion: nil)
                let ac = UIAlertController(title: "Error", message: String(describing: encodingError), preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(ac, animated: true)
                print(encodingError)
            }
        }
    }
    
    
    // 2
    func sendRequest(url : String){
        print(url)
        let parameters: Parameters = [
            "url" : url
        ]
        
        Alamofire.request("https://westus.api.cognitive.microsoft.com/face/v1.0/detect?returnFaceId=true&returnFaceLandmarks=false", method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: self.headers).responseJSON { response in
//            print(response.request!)  // original URL request
//            print(response.response!) // HTTP URL response
//            print(response.data!)     // server data
//            print(response.result)   // result of response serialization
            switch response.result {
                case .success:
                    if let jsonRes = response.result.value {
                        let json = JSON(jsonRes)
                        if(json.isEmpty){
                            self.dismiss(animated: true, completion: nil)
                            let ac = UIAlertController(title: "Error", message: "No Face detected", preferredStyle: .alert)
                            ac.addAction(UIAlertAction(title: "OK", style: .default))
                            self.present(ac, animated: true)
                            return
                        }
//                        else if(json.arrayValue.count > 1){
//                            self.dismiss(animated: true, completion: nil)
//                            let ac = UIAlertController(title: "Notice", message: "There is multiple faces", preferredStyle: .alert)
//                            ac.addAction(UIAlertAction(title: "OK", style: .default))
//                            self.present(ac, animated: true)
//                        }
                        let faceId = json.arrayValue[0]["faceId"].stringValue
                        self.getConfidence(faceId: faceId)
                        //print(json)
//                        for (_,subJson):(String, JSON) in json {
//                            let faceId = subJson["faceId"].stringValue
//                            print(faceId)
//                            // 3
//                            self.getConfidence(faceId: faceId)
//                        }
                    }
                case .failure(let encodingError):
                    self.dismiss(animated: true, completion: nil)
                    print(encodingError)
            }
            
        }
    }
    
    // 3
    func getConfidence(faceId: String){
        let parameters: Parameters = [
            "faceId" : faceId,
            "faceListId" : 4976,
            "maxNumOfCandidatesReturned" : 1,
            "mode" : "matchFace"
        ]
        Alamofire.request("https://westus.api.cognitive.microsoft.com/face/v1.0/findsimilars", method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: self.headers).responseJSON { response in
            //            print(response.request!)  // original URL request
            //            print(response.response!) // HTTP URL response
            //            print(response.data!)     // server data
            //            print(response.result)   // result of response serialization
            switch response.result {
                case .success:
                    if let jsonRes = response.result.value {
                        let json = JSON(jsonRes)
                        print(json)
                        for (_,subJson):(String, JSON) in json {
                            let confidence = subJson["confidence"].stringValue
                            let faceId = subJson["persistedFaceId"].stringValue
                            self.getImage(confidence: confidence, faceId: faceId)
                            //print("\(faceId)")
                            //print("\(confidence)")
                        }
                    }
                case .failure(let encodingError):
                    self.dismiss(animated: true, completion: nil)
                    print(encodingError)
            }
        }
    }
    
    func getImage(confidence: String, faceId: String){
        
        let faceID = faceId.trimmingCharacters(in: .newlines)
        let url = "http://faceurl.azurewebsites.net/celebrity/url/\(faceID)"
        //print(url)
        Alamofire.request(url, method: .get).responseJSON { response in
            //            print(response.request!)  // original URL request
            //            print(response.response!) // HTTP URL response
            //            print(response.data!)     // server data
            //            print(response.result)   // result of response serialization
            switch response.result {
            case .success:
                if let jsonRes = response.result.value {
                    let json = JSON(jsonRes)
                    self.loadImage(url: json["URL"].stringValue, confidence: confidence)
                    //print(json["URL"])
                }
            case .failure(let encodingError):
                self.dismiss(animated: true, completion: nil)
                print(encodingError)
            }
        }
    }
    
    func loadImage(url: String, confidence: String){
        
        let url = URL(string: url)!
        
        let filter = AspectScaledToFitSizeFilter(size: self.returnImage.frame.size)
        
        self.returnImage.af_setImage(
            withURL: url,
            filter: filter,
            imageTransition: .crossDissolve(0.2)
        )
        
        self.returnImage.image = self.returnImage.image?.af_imageRounded(withCornerRadius: 20)
        
        self.result.text = String(Int(round(Double(confidence)!*100))) + "%"
        self.dismiss(animated: true, completion: nil)
    }
    
    func CGRectMake(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    func faceDetect(){
        let inputImage = CIImage(image: sampleImage)!
        let detector = CIDetector.init(ofType: CIDetectorTypeFace,
                                       context: context,
                                       options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        var faceFeatures: [CIFaceFeature]!
        
        //store the detected faces to face features
        if let _: AnyObject = inputImage.properties[kCGImagePropertyOrientation as String] as
            AnyObject? {
            faceFeatures = detector?.features(in: inputImage, options: [CIDetectorSmile: true]) as! [CIFaceFeature]
        }
        else{
            faceFeatures = detector?.features(in: inputImage, options: [CIDetectorSmile: true]) as! [CIFaceFeature]
        }
        
        let inputImageSize = inputImage.extent.size
        //init transform
        var transform = CGAffineTransform.identity
        transform = transform.scaledBy(x: 1, y: -1)
        transform = transform.translatedBy(x: 0, y: -inputImageSize.height)
        
        if faceFeatures.isEmpty {
            //no face detected
            let alert = UIAlertController(title: "Sorry", message: "Cannot find faces", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }else{
            for faceFeature in faceFeatures {
                var faceViewBounds = faceFeature.bounds.applying(transform)
                
                // scale the frame
                let scale = min(userImage.bounds.size.width / inputImageSize.width,
                                userImage.bounds.size.height / inputImageSize.height)
                let offsetX = (userImage.bounds.size.width - inputImageSize.width * scale) / 2
                let offsetY = (userImage.bounds.size.height - inputImageSize.height * scale) / 2
                
                faceViewBounds = faceViewBounds.applying(CGAffineTransform(scaleX: scale, y: scale))
                faceViewBounds.origin.x += offsetX
                faceViewBounds.origin.y += offsetY
                
                let faceView = UIView(frame: faceViewBounds)
                faceView.frame = CGRectMake(faceViewBounds.origin.x, faceViewBounds.origin.y, faceViewBounds.width*1.2, faceViewBounds.height*1.2)
                faceView.layer.borderWidth = 2
                self.userImage.addSubview(faceView)
            }
        }
    }
    
    func generateRandomStringWithLength(length: Int) -> String {
        
        var randomString = ""
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        
        for _ in 1...length {
            let randomIndex  = Int(arc4random_uniform(UInt32(letters.characters.count)))
            let a = letters.index(letters.startIndex, offsetBy: randomIndex)
            randomString +=  String(letters[a])
        }
        
        return randomString
    }
}


