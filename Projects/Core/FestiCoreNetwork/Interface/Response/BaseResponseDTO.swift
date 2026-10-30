//
//  BaseResponseDTO.swift
//  FestiCoreNetwork
//
//  Created by FestiCore on 10/31/26.
//

public struct BaseResponseDTO<DataDTO: Decodable & Sendable>: Decodable, Sendable {
  public let code: String
  public let message: String
  public let data: DataDTO

  public init(code: String, message: String, data: DataDTO) {
    self.code = code
    self.message = message
    self.data = data
  }
}

extension BaseResponseDTO: Equatable where DataDTO: Equatable {}
