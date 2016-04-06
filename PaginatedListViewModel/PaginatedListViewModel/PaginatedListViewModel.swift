//
//  PaginatedListViewModel.swift
//  PaginatedListViewModel
//
//  Created by Sergey Gavrilyuk on 2016-03-17.
//  Copyright © 2016 Sergey Gavrilyuk. All rights reserved.
//

import Foundation
import ReactiveCocoa
import Result

public class RecusrsivePageSignalPayload<T> {
    let page: [T]
    let nextPageSignal: SignalProducer<RecusrsivePageSignalPayload<T>, NSError>?
    
    public init(currentPage: [T], nextPageSignal: SignalProducer<RecusrsivePageSignalPayload<T>, NSError>?) {
        self.page = currentPage
        self.nextPageSignal = nextPageSignal
    }
}

public protocol PaginatedListViewModelDependency {
    typealias ListItemType
    func intialPageSignal() -> SignalProducer<RecusrsivePageSignalPayload<ListItemType>, NSError>
}

public class PaginatedListViewModel<T> {
    
    private let loadNextPageTrigger = Signal<(),NoError>.pipe()
    private let resetTrigger = Signal<(), NoError>.pipe()
    
    public let exhausted: AnyProperty<Bool>
    public let loading: AnyProperty<Bool>
    public let lastError: AnyProperty<NSError?>
    public let items: AnyProperty<[T]>
    
    public init<C: PaginatedListViewModelDependency where C.ListItemType == T>(dependency: C) {
        
        let __exhausted = MutableProperty(false)
        let __loading = MutableProperty(false)
        let __nextPage = MutableProperty<SignalProducer<RecusrsivePageSignalPayload<T>, NSError>?>(nil)
        
        let (lastErrorSignal, lastErrorSink) = Signal<NSError?, NoError>.pipe()
        
        let loadnextPageSignal = self.loadNextPageTrigger.0.producer()
        let loadNextPageTrigger = combineLatest(__exhausted.producer, __loading.producer)
            .map { !$0 && !$1 }
            .flatMap(.Latest) {
                return $0 ? loadnextPageSignal : .never
        }
        
        let itemsSignal = self.resetTrigger.0.flatMap(.Latest) {_ -> SignalProducer<[T], NoError> in
            __nextPage.value = dependency.intialPageSignal()
            __exhausted.value = false
            lastErrorSink.sendNext(nil)
            
            let loadedPagesSignal = loadNextPageTrigger.flatMap(.Merge) { _ -> SignalProducer<[T], NoError> in
                if let nextPageSignalProducer = __nextPage.value {
                    return nextPageSignalProducer
                        .observeOn(UIScheduler())
                        .on(started: { lastErrorSink.sendNext(nil) }) //reset any error
                        .on(started: { __loading.value = true },
                            terminated: { __loading.value = false })
                        .redirectErrors(Observer { lastErrorSink.sendNext($0) })
                        .on { payload in
                            if let nextPage = payload.nextPageSignal {
                                __nextPage.value = nextPage
                            } else {
                                __nextPage.value = nil
                                __exhausted.value = true
                            }
                        }
                        .map { return $0.page }
                } else {
                    return .empty
                }
            }
            
            
            let pagesSignal = SignalProducer<[T], NoError>(value: []).concat(loadedPagesSignal)
            return pagesSignal.scan([], {(var all, current) in
                all.appendContentsOf(current)
                return all
            })
        }
        
        self.lastError = AnyProperty(initialValue: nil, signal: lastErrorSignal)
        self.exhausted = AnyProperty(__exhausted)
        self.loading = AnyProperty(__loading)
        self.items = AnyProperty(initialValue: [], signal: itemsSignal)
        
        self.reset() // initialization state
    }
    
    public func loadNextPage() {
        self.loadNextPageTrigger.1.sendNext()
    }
    
    public func reset() {
        self.resetTrigger.1.sendNext()
    }
    
    public func reload() {
        self.reset()
        self.loadNextPage()
    }
}




