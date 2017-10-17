//
//  Utils.swift
//  PaginatedListViewModel
//
//  Created by Sergii Gavryliuk on 2016-03-17.
//  Copyright © 2016 Sergey Gavrilyuk. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result

extension Signal {
  
  func producer() -> SignalProducer<Value, Error> {
    return SignalProducer {
      sink, disposables in
      self.observe(sink)
    }
  }
}

extension SignalProducer {
  
  func ignoreErrors() -> SignalProducer<Value, NoError> {
    return self.flatMapError { _ in .empty }
  }
  
  func redirectErrors(on observer: Signal<Error, NoError>.Observer) -> SignalProducer<Value, NoError> {
    return self
      .on (failed: { observer.send(value: $0) } )
      .ignoreErrors()
  }
}

