
import UIKit

class ImageStore {
    
    let cache = NSCache<NSString,UIImage>()
    
    func setImage(image: UIImage, forKey key: NSString) {
        cache.setObject(image, forKey: key)
        // Create full URL for image
        let imageURL = imageURLForKey(key: key as String)
        // Turn image into JPEG data
        if let data = image.jpegData(compressionQuality: 0.5) {
            // Write it to full URL
            do {
                try data.write(to: imageURL as URL)
            } catch let error {
                print("error while writing - \(error)")
            }
        }
        
    }
    
    
    func imageForKey(key: String) -> UIImage? {
        if let existingImage = cache.object(forKey: key as NSString){//} as? UIImage {
            return existingImage
        }
        let imageURL = imageURLForKey(key: key)
        guard let imageFromDisk = UIImage(contentsOfFile: imageURL.path!) else {
            return nil
        }
        cache.setObject(imageFromDisk, forKey: key as NSString)
        return imageFromDisk
    }
    
    
    func deleteImageForKey(key: String) {
        cache.removeObject(forKey: key as NSString)
        
        let imageURL = imageURLForKey(key: key)
        do {
            try FileManager.default.removeItem(at: imageURL as URL)
        }
        catch let deleteError {
            print("Error removing the image from disk: \(deleteError)")
        }
        
    }
    
    
    func imageURLForKey(key: String) -> NSURL {
        let documentsDirectories = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentDirectory = documentsDirectories.first!
        
        return documentDirectory.appendingPathComponent(key) as NSURL
    }
}
