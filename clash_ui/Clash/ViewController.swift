//
//  ViewController.swift
//  Clash
//
//  Created by Filip Pawłowski on 18/11/2023.
//

import UIKit
import CoreML
import Vision
import ImageIO

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    var customColor: UIColor!  // Global variable for color
    var disposalDescriptions: [String: String] = [:] // Helps with JSON file

    // MARK: - IBOutlets
    @IBOutlet weak var displayWindow: UIImageView!
    @IBOutlet weak var classLabel: UILabel!
    @IBOutlet weak var selectButton: UIButton!
    @IBOutlet weak var takeImageButton: UIButton!
    @IBOutlet weak var modelConfidence: UILabel!
    @IBOutlet weak var disposalDescription: UILabel!
    
    // MARK: - Design
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        customColor = UIColor(red:1/255.0, green: 24/255.0, blue: 26/255.0, alpha: 1.0)
        
        // Set the placeholder image as the initial image
        displayWindow.image = UIImage(named: "placeholder")
        
        displayWindow.layer.cornerRadius = 10
        displayWindow.layer.borderColor = customColor.cgColor
        displayWindow.layer.borderWidth = 4
        
        selectButton.layer.cornerRadius = 20
        
        takeImageButton.layer.borderColor = customColor.cgColor
        takeImageButton.layer.borderWidth = 3
        takeImageButton.layer.cornerRadius = 20
        takeImageButton.clipsToBounds = true
        
        
        // MARK: - Load JSON
        loadDisposalDescriptions()
        
        func loadDisposalDescriptions() {
                guard let url = Bundle.main.url(forResource: "DisposalDescriptions", withExtension: "json"),
                      let data = try? Data(contentsOf: url) else {
                    print("Error loading JSON file")
                    return
                }

                do {
                    disposalDescriptions = try JSONDecoder().decode([String: String].self, from: data)
                } catch {
                    print("Error parsing JSON file: \(error)")
                }
            }

    }
    // MARK: - Photo selection actions
    @IBAction func selectPhoto() {
        presentPhotoPicker(sourceType: .photoLibrary)
    }
    
    @IBAction func takePicture() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            print("Camera not available")
            return
        }
        presentPhotoPicker(sourceType: .camera)
    }
    // MARK: - Helper Method for Image Picker
    func presentPhotoPicker(sourceType: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = sourceType
        present(picker, animated: true)
    }
    
    
//    // MARK: - Disposal description
    func updateDisposalDescription(for classification: String) {
        var adjustedClassification = classification

        // Map 'metal' to 'plastic' and 'cardboard' to 'paper'
        if classification == "metal" {
            adjustedClassification = "plastic"
        } else if classification == "cardboard" {
            adjustedClassification = "paper"
        }

        if let description = disposalDescriptions[adjustedClassification] {
            disposalDescription.text = description
        } else {
            disposalDescription.text = "No specific disposal instructions available."
        }
    }

    // MARK: - Image Picker Delegate
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)

        // Extracting the original image from the picker info
        if let image = info[.originalImage] as? UIImage {
            displayWindow.image = image
            // Call a method to handle any further classification or processing of the image
            updateClassifications(for: image)
        }
    }
    
    func updateClassifications(for image: UIImage) {
        classLabel.text = "Classifying..."
        
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        guard let ciImage = CIImage(image: image) else { fatalError("Unable to create \(CIImage.self) from \(image).") }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
            do {
                try handler.perform([self.classificationRequest])
            } catch {
                /*
                 This handler catches general image processing errors. The `classificationRequest`'s
                 completion handler `processClassifications(_:error:)` catches errors specific
                 to processing that request.
                 */
                print("Failed to perform classification.\n\(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Image Classification
    lazy var classificationRequest: VNCoreMLRequest = {
        do {
            //let model = try VNCoreMLModel(for: MobileNet().model)
            let model = try VNCoreMLModel(for: clash_model().model)
            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                self?.processClassifications(for: request, error: error)
            })
            request.imageCropAndScaleOption = .centerCrop
            return request
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()

    
    func processClassifications(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let results = request.results else {
                self.classLabel.text = "Unable to classify image."
                self.modelConfidence.text = "Error"
                return
            }
            let classifications = results as! [VNClassificationObservation]

            if classifications.isEmpty {
                self.classLabel.text = "Prediction: None"
                self.modelConfidence.text = "ClashModel - 0%"
            } else {
                // Display only the top classification
                let topClassification = classifications.first!
                self.classLabel.text = "Prediction: \(topClassification.identifier)"
                self.modelConfidence.text = String(format: "ClashModel - %.2f%%", topClassification.confidence * 100)

                // Update the disposal description based on the classification
                self.updateDisposalDescription(for: topClassification.identifier)

                // Update the border color based on the classification
                self.updateBorderColor(for: topClassification.identifier)
            }
        }
    }
    
    func updateBorderColor(for classification: String) {
        switch classification {
        case "plastic","metal":
            displayWindow.layer.borderColor = CGColor(red: 230/255.0, green: 185/255.0, blue: 9/255.0, alpha: 1.0)
        case "paper","cardboard":
            displayWindow.layer.borderColor = CGColor(red: 9/255.0, green: 68/255.0, blue: 230/255.0, alpha: 1.0)
        case "glass":
            displayWindow.layer.borderColor = CGColor(red: 7/255.0, green: 133/255.0, blue: 19/255.0, alpha: 1.0)
        case "organic":
            displayWindow.layer.borderColor = CGColor(red: 99/255.0, green: 55/255.0, blue: 1/255.0, alpha: 1.0)
        case "trash":
            displayWindow.layer.borderColor = UIColor.black.cgColor
        default:
            displayWindow.layer.borderColor = customColor.cgColor // Use customColor for other classifications
        }
    }
    
}
