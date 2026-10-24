//
//  AuthenticatedClientProvider.swift
//  FestiCoreAuthInterface
//
//  Created by FestiCore on 10/24/26.
//

import FestiCoreNetworkInterface

public protocol AuthenticatedClientProvider: Sendable {
  var authenticatedClient: any FestiCoreNetworkClient { get }
}
