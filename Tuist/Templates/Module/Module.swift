//
//  Module.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription
import Foundation

let layer = Template.Attribute.required("layer")
let name = Template.Attribute.required("name")
let author = Template.Attribute.required("author")
let dateFormatter = DateFormatter()
dateFormatter.dateFormat = "yyyy/MM/dd"
let currentDate = Template.Attribute.optional("currentDate", default: .string(dateFormatter.string(from: Date())))

let template = Template(
  description: "FestiCore 모듈 생성",
  attributes: [layer, name, author, currentDate],
  items: [
    .file(path: "Projects/\(layer)/\(name)/Project.swift", templatePath: "Project.stencil"),
    .file(path: "Projects/\(layer)/\(name)/Sources/\(name).swift", templatePath: "Source.stencil"),
    .file(path: "Projects/\(layer)/\(name)/Tests/\(name)Tests.swift", templatePath: "Test.stencil")
  ]
)
