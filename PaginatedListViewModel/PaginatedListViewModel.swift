//
//  PaginatedListViewModel.swift
//  PaginatedListViewModel
//
//  Created by Sergey Gavrilyuk on 2016-03-17.
//  Copyright © 2016 Sergey Gavrilyuk. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result

public class RecusrsivePageSignalPayload<T, E: Error> {
  let page: [T]
  let nextPageSignal: SignalProducer<RecusrsivePageSignalPayload<T, E>, E>?
  
  public init(currentPage: [T], nextPageSignal: SignalProducer<RecusrsivePageSignalPayload<T, E>, E>?) {
    self.page = currentPage
    self.nextPageSignal = nextPageSignal
  }
}

public protocol PaginatedListViewModelDependency {
  associatedtype ListItemType
  associatedtype ErrorType: Error
  func intialPageSignal() -> SignalProducer<RecusrsivePageSignalPayload<ListItemType, ErrorType>, ErrorType>
}

public class PaginatedListViewModel<T, E: Error> {
  
  private let loadNextPageTrigger = Signal<(),NoError>.pipe()
  private let resetTrigger = Signal<(), NoError>.pipe()
  
  public let exhausted: Property<Bool>
  public let loading: Property<Bool>
  public let lastError: Property<E?>
  public let items: Property<[T]>
  
  public init<C: PaginatedListViewModelDependency>(dependency: C)  where C.ListItemType == T, C.ErrorType == E {
    
    let __exhausted = MutableProperty(false)
    let __loading = MutableProperty(false)
    let __nextPage = MutableProperty<SignalProducer<RecusrsivePageSignalPayload<T, E>, E>?>(nil)
    
    let (lastErrorSignal, lastErrorSink) = Signal<E?, NoError>.pipe()
    
    let loadnextPageSignal = self.loadNextPageTrigger.0.producer()
    
    let loadNextPageTrigger = SignalProducer.combineLatest(__exhausted.producer, __loading.producer)
      .map { !$0 && !$1 }
      .flatMap(.latest) {
        return $0 ? loadnextPageSignal : .never
    }
    
    let itemsSignal = self.resetTrigger.0.flatMap(.latest) {_ -> SignalProducer<[T], NoError> in
      __nextPage.value = dependency.intialPageSignal()
      __exhausted.value = false
      lastErrorSink.send(value: nil)
      
      let loadedPagesSignal = loadNextPageTrigger.flatMap(.merge) { _ -> SignalProducer<[T], NoError> in
        if let nextPageSignalProducer = __nextPage.value {
          return nextPageSignalProducer
            .observe(on: UIScheduler())
            .on(started: { lastErrorSink.send(value: nil) }) //reset any error
            .on(started: { __loading.value = true },
                terminated: { __loading.value = false })
            .redirectErrors(on: Signal.Observer (value: { lastErrorSink.send(value: $0) }))
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
      return pagesSignal.scan([], {( all, current) in
        return all + current
      })
    }
    
    self.lastError = Property(initial: nil, then: lastErrorSignal)
    self.exhausted = Property(__exhausted)
    self.loading = Property(__loading)
    self.items = Property(initial: [], then: itemsSignal)
    
    self.reset() // initialization state
  }
  
  public func loadNextPage() {
    self.loadNextPageTrigger.1.send(value: ())
  }
  
  public func reset() {
    self.resetTrigger.1.send(value: ())
  }
  
  public func reload() {
    self.reset()
    self.loadNextPage()
  }
}




