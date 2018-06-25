//
//  FlickrJSONstruct.swift
//  FlickFinder
//
//  Created by Erich Clark on 6/24/18.
//  Copyright © 2018 Udacity. All rights reserved.
//

import Foundation

struct FlickrJSONstruct: Codable {
    var photos: PhotoJSONstruct?
    var stat: String
}

struct PhotoJSONstruct: Codable {
    var page: Int
    var pages: Int
    var perpage: Int
    var total: String
    var photo: [Photo]
}

struct Photo: Codable {
    var title: String?
    var url_m: URL?
}
