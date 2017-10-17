//
//  PaginatedListViewModelTests.swift
//  PaginatedListViewModelTests
//
//  Created by Sergii Gavryliuk on 2016-03-17.
//  Copyright © 2016 Sergey Gavrilyuk. All rights reserved.
//

import XCTest
import ReactiveSwift

@testable import PaginatedListViewModel

enum TestError: Error  { case someError }

typealias TestSignalPayload = RecusrsivePageSignalPayload<String, TestError>
typealias TestSignal = Signal<TestSignalPayload, TestError>
typealias TestSignalProducer = SignalProducer<TestSignalPayload, TestError>
typealias TestSink = Signal<TestSignalPayload, TestError>.Observer

enum PageSignalResolveType {
  case Success
  case Fail(TestError)
}

class PaginatedListViewModelTests: XCTestCase {
  
  
  override func setUp() {
    super.setUp()
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }
  
  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    super.tearDown()
  }
  
  func generatePageSignals(pages: [[String]]) -> (TestSignalProducer, (_ resolveType: PageSignalResolveType) -> Void ) {
    guard pages.count > 0 else {
      fatalError("Cannot create sequence of 0 signals")
    }
    
    var localPages = pages
    
    var sendNextStack: [(PageSignalResolveType) -> ()] = []
    
    func sendNext(resolveType: PageSignalResolveType) {
      sendNextStack.popLast()?(resolveType)
    }
    
    let lastPage = localPages.popLast()!
    var runningPageProducer = TestSignalProducer() {
      sink, _ in
      let(lastPageSignal, lastPageSink) = TestSignal.pipe()
      lastPageSignal.observe(sink)
      
      sendNextStack.append({ (resolveType: PageSignalResolveType) in
        switch resolveType {
        case .Success:
          lastPageSink.send(value: TestSignalPayload(currentPage:lastPage , nextPageSignal: nil))
          lastPageSink.sendCompleted()
        case .Fail(let error):
          lastPageSink.send(error: error)
        }
      })
    }
    
    while let page = localPages.popLast() {
      
      let scopedPageProducer = runningPageProducer
      runningPageProducer = TestSignalProducer() {
        sink, disposables in
        let (prevPageSignal, prevSink) = TestSignal.pipe()
        prevPageSignal.observe(sink)
        sendNextStack.append({ (resolveType: PageSignalResolveType) in
          switch resolveType {
          case .Success:
            prevSink.send(value: TestSignalPayload(currentPage: page, nextPageSignal: scopedPageProducer))
            prevSink.sendCompleted()
          case .Fail(let error):
            prevSink.send(error: error)
          }
        })
      }
    }
    
    return (runningPageProducer, sendNext)
  }
  
  func testInitialLoadingProperty() {
    
    let (producer, _) = generatePageSignals(pages: [[""]])
    
    let dep = DynamicPaginatedListViewModelDep(firstPageSignal: producer)
    let viewModel = PaginatedListViewModel(dependency: dep)
    
    
    XCTAssertEqual(viewModel.loading.value, false, "loading should be false before initial `loadNextPage` called")
    viewModel.loadNextPage()
    
    XCTAssertEqual(viewModel.loading.value, true, "loading should be true when `loadNextPage` called")
  }
  
  func testLoadingProperty() {
    
    let (firstPageSignal, deliverNextPage) = generatePageSignals(pages: [["1"], ["2"]])
    
    let dep = DynamicPaginatedListViewModelDep(firstPageSignal: firstPageSignal)
    
    let viewModel = PaginatedListViewModel(dependency: dep)
    viewModel.loadNextPage()
    
    deliverNextPage(.Success)
    
    XCTAssertEqual(viewModel.loading.value, false, "loading should be false after signall page signal completed with result")
    
    viewModel.loadNextPage()
    
    XCTAssertEqual(viewModel.loading.value, true, "loading should be true when `loadNextPage` called")
    
    deliverNextPage(.Success)
    
    XCTAssertEqual(viewModel.loading.value, false, "loading should be false after signall page signal completed with result")
    
  }
  
  func testExchaustedProperty() {
    
    let (firstPageSignal, deliverNextPage) = generatePageSignals(pages: [["1"], ["2"]])
    
    let dep = DynamicPaginatedListViewModelDep(firstPageSignal: firstPageSignal)
    
    let viewModel = PaginatedListViewModel(dependency: dep)
    
    XCTAssertEqual(viewModel.exhausted.value, false, "exhausted should be false initially")
    
    viewModel.loadNextPage()
    
    XCTAssertEqual(viewModel.exhausted.value, false, "exhausted should be false until page loaded")
    
    deliverNextPage(.Success)
    
    XCTAssertEqual(viewModel.exhausted.value, false, "exhausted should be false since next page available")
    
    viewModel.loadNextPage()
    
    XCTAssertEqual(viewModel.exhausted.value, false, "exhausted should be false until page is loaded")
    
    deliverNextPage(.Success)
    
    XCTAssertEqual(viewModel.exhausted.value, true, "exhausted should be true since no next page available")
    
    viewModel.reset()
    
    XCTAssertEqual(viewModel.exhausted.value, false, "exhausted should be false after reset()")
  }
  
  func testLastError() {
    
    let (firstPageSignal, deliverNextPage) = generatePageSignals(pages: [["1"], ["2"], ["3"]])
    
    let dep = DynamicPaginatedListViewModelDep(firstPageSignal: firstPageSignal)
    
    let viewModel = PaginatedListViewModel(dependency: dep)
    
    XCTAssert(viewModel.lastError.value == nil, "lastError should be nil initially")
    
    viewModel.loadNextPage()
    
    XCTAssert(viewModel.lastError.value == nil, "lastError should be nil before page is delivered")
    
    deliverNextPage(.Success)
    
    XCTAssert(viewModel.lastError.value == nil, "lastError should be nil since page was delivered successfully")
    
    viewModel.loadNextPage()
    
    let error = TestError.someError
    deliverNextPage(.Fail(error))
    
    XCTAssert(viewModel.lastError.value == error, "lastError should be equal to error delivered by pageSignal")
    
    viewModel.loadNextPage()
    
    XCTAssert(viewModel.lastError.value == nil, "lastError should be reset to nil when new `loadNextPage` called")
    
    deliverNextPage(.Success)
    
    XCTAssert(viewModel.lastError.value == nil, "lastError should be nil when new page delivered successfully")
    
    viewModel.loadNextPage()
    deliverNextPage(.Fail(error))
    
    XCTAssertEqual(viewModel.lastError.value, error, "lastError should be equal to error delivered by pageSignal")
    
    viewModel.reset()
    
    XCTAssert(viewModel.lastError.value == nil, "lastError should be nil after `reset`")
    
  }
  
  
  func testPagesConsistency() {
    
    let (firstPageSignal, deliverNextPage) = generatePageSignals(pages: [["1", "2"], ["3", "4"]])
    
    let dep = DynamicPaginatedListViewModelDep(firstPageSignal: firstPageSignal)
    
    let viewModel = PaginatedListViewModel(dependency: dep)
    
    
    XCTAssertEqual(viewModel.items.value, [], "item should be empty initially")
    
    viewModel.loadNextPage()
    
    deliverNextPage(.Success)
    
    XCTAssertEqual(viewModel.items.value, ["1", "2"], "item should match first page")
    
    viewModel.loadNextPage()
    deliverNextPage(.Success)
    
    XCTAssertEqual(viewModel.items.value, ["1", "2", "3", "4"], "item should match first + second page")
    
    viewModel.reset()
    
    XCTAssertEqual(viewModel.items.value, [], "item should empty after `reset`")
    
  }
  
  
}

struct DynamicPaginatedListViewModelDep: PaginatedListViewModelDependency {
  typealias ListItemType = String
  typealias ErrorType = TestError
  let firstPageSignal: SignalProducer<RecusrsivePageSignalPayload<String, ErrorType>, ErrorType>
  
  func intialPageSignal() -> SignalProducer<RecusrsivePageSignalPayload<String, ErrorType>, ErrorType> {
    return self.firstPageSignal
  }
  
  init(firstPageSignal: SignalProducer<RecusrsivePageSignalPayload<String, ErrorType>, ErrorType>) {
    self.firstPageSignal = firstPageSignal
  }
}

