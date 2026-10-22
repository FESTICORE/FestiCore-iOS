//
//  SecureStorageError.swift
//  FestiCoreStorageInterface
//
//  Created by FestiCore on 10/22/26.
//

import Foundation

public enum SecureStorageError: Error {
  case invalidData
  case unexpectedStatus(OSStatus)
}
