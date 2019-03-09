//
//  FlickrAPI.swift
//  Photorama
//
//  Created by SKC on 1/5/19.
//  Copyright © 2019 SKC-PRO. All rights reserved.
//

import Foundation
import CoreData

enum FlickrError: Error {
    case invalidJSONData
}

enum Method: String {
    //    case interestingPhotos = "flickr.galleries.getPhotos" // My Flickr endpoint
    case interestingPhotos = "1456473281/self/media/recent/"
}

struct FlickrAPI {
    
    private static let baseURLString = "https://api.instagram.com/v1/users/self/media/recent/"
    //    private static let apiKey = "50351ad920360be53cc75dd286437612" // My Flickr Token
    private static let apiKey = "7311719624.1677ed0.a5cd3849e94b429e8eeba70a1f826819" // My Insta Token
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    
    private static func flickrURL(method: Method, parameters: [String: String]?) -> URL {
        
        var components = URLComponents(string: baseURLString)!
        
        var queryItems = [URLQueryItem]()
        
        let baseParams = [
            //            "method" : method.rawValue,
            //            "format" : "json",
            //            "nojsoncallback" : "1",
            "access_token" : apiKey,
            //            "gallery_id" : "66911286-72157647277042064"
        ]
        
        for (key, value) in baseParams {
            let item = URLQueryItem(name: key, value: value)
            queryItems.append(item)
        }
        
        if let additionalParams = parameters {
            for (key, value) in additionalParams {
                let item = URLQueryItem(name: key, value: value)
                queryItems.append(item)
            }
        }
        components.queryItems = queryItems
        return components.url!
    }
    
    
    static var interestingPhotosURL: URL {
        let url = flickrURL(method: .interestingPhotos, parameters: [:/*"extras": "url_h,date_taken"*/])
        //        print(url)
        return url
        
    }
    
    
    static func photos(fromJSON data: Data, into context: NSManagedObjectContext) -> PhotosResult {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data,options: [])
            var photosArray = [[String:Any]]()
            
            guard
                let jsonDictionary = jsonObject as? [AnyHashable:Any],
                let primaryArray = jsonDictionary["data"] as? [[String:Any]] else {
                    return .failure(FlickrError.invalidJSONData)
            }
            for item in primaryArray {
                let id = item["id"] as! String
                let index = id.index(of: "_")!
                let newId = String(id[..<index])

                let caption = item["caption"] as! [String:Any]
                let text = caption["text"] as! String
                let dateTaken = caption["created_time"] as! String
                let images = item["images"] as! [String:Any]
                var photoBundle = images["standard_resolution"] as! [String:Any]
                photoBundle["id"] = newId
                photoBundle["datetaken"] = dateTaken
                photoBundle["text"] = text
                photosArray.append(photoBundle)
            }
            
            var finalPhotos = [Photo]()
            for photoJSON in photosArray {
                if let photo = photo(fromJSON: photoJSON, into: context) {
                    finalPhotos.append(photo)
                }
            }
            if finalPhotos.isEmpty && !photosArray.isEmpty {
                // We weren't able to parse any of the photos
                // Maybe the JSON format for photos has changed
                return .failure(FlickrError.invalidJSONData)
            }
            return .success(finalPhotos)
        } catch let error {
            return .failure(error)
        }
    }
    
    
    private static func photo(fromJSON json: [String : Any], into context: NSManagedObjectContext) -> Photo? {
        guard
            let photoID = json["id"] as? String,
            let text = json["text"] as? String,
            let photoURLString = json["url"] as? String,
            let url = URL(string: photoURLString),
            let date = json["datetaken"] as? String
            else {
                // Don't have enough information to construct a Photo
                return nil
        }
        let doubleTimeInterval = Double(date)
        let dateTaken  = Date.init(timeIntervalSince1970: doubleTimeInterval!)
        
        let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
        let predicate = NSPredicate(format: "\(#keyPath(Photo.photoID)) == \(photoID)")

        fetchRequest.predicate = predicate
        var fetchedPhotos: [Photo]?
        context.performAndWait {
            fetchedPhotos = try? fetchRequest.execute()
        }
        if let existingPhoto = fetchedPhotos?.first {
            return existingPhoto
        }
        
        var photo: Photo!
        context.performAndWait {
            photo = Photo(context: context)
            photo.text = text
            photo.photoID = photoID
            photo.remoteURL = url as NSURL
            photo.dateTaken = dateTaken as NSDate
        }
        return photo
    }
}
