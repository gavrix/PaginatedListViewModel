//
//  Utils.swift
//  PaginatedListViewModel
//
//  Created by Sergii Gavryliuk on 2016-03-17.
//  Copyright © 2016 Sergey Gavrilyuk. All rights reserved.
//

import Foundation
import ReactiveCocoa
import Result

extension Signal {

    func producer() -> SignalProducer<Value, Error> {
        return SignalProducer {
            sink, disposables in
            self.observe(sink)
        }
    }
}

extension SignalProducerType where Self.Error == NSError {
    
    func ignoreErrors() -> SignalProducer<Self.Value, NoError> {
        return self.flatMapError { _ in .empty }
    }
    
    func redirectErrors(observer: Observer<NSError, NoError>) -> SignalProducer<Self.Value, NoError> {
        return self
            .on (failed: { observer.sendNext($0) } )
            .ignoreErrors()
    }
}