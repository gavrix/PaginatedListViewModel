//
//  PaginatedListViewModelTests.swift
//  PaginatedListViewModelTests
//
//  Created by Sergii Gavryliuk on 2016-03-17.
//  Copyright © 2016 Sergey Gavrilyuk. All rights reserved.
//

import XCTest
import ReactiveCocoa

@testable import PaginatedListViewModel

typealias TestSignalPayload = RecusrsivePageSignalPayload<String>
typealias TestSignal = Signal<TestSignalPayload, NSError>
typealias TestSignalProducer = SignalProducer<TestSignalPayload, NSError>
typealias TestSink = Observer<TestSignalPayload, NSError>

enum PageSignalResolveType {
    case Success
    case Fail(NSError)
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
    
    func generatePageSignals(pages: [[String]]) -> (TestSignalProducer, (resolveType: PageSignalResolveType) -> Void ) {
        guard pages.count > 0 else {
            fatalError("Cannot create sequence of 0 signals")
        }

        var localPages = pages
        
        var sendNextStack: [(resolveType: PageSignalResolveType) -> ()] = []

        func sendNext(resolveType: PageSignalResolveType) {
            sendNextStack.popLast()?(resolveType: resolveType)
        }
        
        let lastPage = localPages.popLast()!
        var runningPageProducer = TestSignalProducer() {
            sink, _ in
            let(lastPageSignal, lastPageSink) = TestSignal.pipe()
            lastPageSignal.observe(sink)
            
            sendNextStack.append({ (resolveType: PageSignalResolveType) in
                switch resolveType {
                case .Success:
                    lastPageSink.sendNext(TestSignalPayload(currentPage:lastPage , nextPageSignal: nil))
                    lastPageSink.sendCompleted()
                case .Fail(let error):
                    lastPageSink.sendFailed(error)
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
                        prevSink.sendNext(TestSignalPayload(currentPage: page, nextPageSignal: scopedPageProducer))
                        prevSink.sendCompleted()
                    case .Fail(let error):
                        prevSink.sendFailed(error)
                    }
                })
            }
        }
        
        return (runningPageProducer, sendNext)
    }
    
    func testInitialLoadingProperty() {
        
        let (producer, _) = generatePageSignals([[""]])
        
        let dep = DynamicPaginatedListViewModelDep(firstPageSignal: producer)
        let viewModel = PaginatedListViewModel(dependency: dep)
        
        
        XCTAssertEqual(viewModel.loading.value, false, "loading should be false before initial `loadNextPage` called")
        viewModel.loadNextPage()
        
        XCTAssertEqual(viewModel.loading.value, true, "loading should be true when `loadNextPage` called")
    }
    
    func testLoadingProperty() {
        
        let (firstPageSignal, deliverNextPage) = generatePageSignals([["1"], ["2"]])

        let dep = DynamicPaginatedListViewModelDep(firstPageSignal: firstPageSignal)

        let viewModel = PaginatedListViewModel(dependency: dep)
        viewModel.loadNextPage()
        
        deliverNextPage(resolveType: .Success)
        
        XCTAssertEqual(viewModel.loading.value, false, "loading should be false after signall page signal completed with result")
        
        viewModel.loadNextPage()
        
        XCTAssertEqual(viewModel.loading.value, true, "loading should be true when `loadNextPage` called")
        
        deliverNextPage(resolveType: .Success)
        
        XCTAssertEqual(viewModel.loading.value, false, "loading should be false after signall page signal completed with result")

    }
    
    func testExchaustedProperty() {
        
        let (firstPageSignal, deliverNextPage) = generatePageSignals([["1"], ["2"]])
        
        let dep = DynamicPaginatedListViewModelDep(firstPageSignal: firstPageSignal)

        let viewModel = PaginatedListViewModel(dependency: dep)
        
        XCTAssertEqual(viewModel.exhausted.value, false, "exhausted should be false initially")
        
        viewModel.loadNextPage()
        
        XCTAssertEqual(viewModel.exhausted.value, false, "exhausted should be false until page loaded")
        
        deliverNextPage(resolveType: .Success)
        
        XCTAssertEqual(viewModel.exhausted.value, false, "exhausted should be false since next page available")

        viewModel.loadNextPage()
        
        XCTAssertEqual(viewModel.exhausted.value, false, "exhausted should be false until page is loaded")

        deliverNextPage(resolveType: .Success)
        
        XCTAssertEqual(viewModel.exhausted.value, true, "exhausted should be true since no next page available")
        
        viewModel.reset()
        
        XCTAssertEqual(viewModel.exhausted.value, false, "exhausted should be false after reset()")
    }
    
    func testLastError() {

        let (firstPageSignal, deliverNextPage) = generatePageSignals([["1"], ["2"], ["3"]])
        
        let dep = DynamicPaginatedListViewModelDep(firstPageSignal: firstPageSignal)
        
        let viewModel = PaginatedListViewModel(dependency: dep)
        
        XCTAssertEqual(viewModel.lastError.value, nil, "lastError should be nil initially")
        
        viewModel.loadNextPage()
        
        XCTAssertEqual(viewModel.lastError.value, nil, "lastError should be nil before page is delivered")
        
        deliverNextPage(resolveType: .Success)
        
        XCTAssertEqual(viewModel.lastError.value, nil, "lastError should be nil since page was delivered successfully")
        
        viewModel.loadNextPage()

        let error = NSError(domain: "SampleDomain", code: 0, userInfo: nil)
        deliverNextPage(resolveType: .Fail(error))
        
        XCTAssertEqual(viewModel.lastError.value, error, "lastError should be equal to error delivered by pageSignal")
        
        viewModel.loadNextPage()

        XCTAssertEqual(viewModel.lastError.value, nil, "lastError should be reset to nil when new `loadNextPage` called")
        
        deliverNextPage(resolveType: .Success)
        
        XCTAssertEqual(viewModel.lastError.value, nil, "lastError should be nil when new page delivered successfully")
        
        viewModel.loadNextPage()
        deliverNextPage(resolveType: .Fail(error))
        
        XCTAssertEqual(viewModel.lastError.value, error, "lastError should be equal to error delivered by pageSignal")

        viewModel.reset()
        
        XCTAssertEqual(viewModel.lastError.value, nil, "lastError should be nil after `reset`")

    }
    
    
    func testPagesConsistency() {
     
        let (firstPageSignal, deliverNextPage) = generatePageSignals([["1", "2"], ["3", "4"]])
        
        let dep = DynamicPaginatedListViewModelDep(firstPageSignal: firstPageSignal)
        
        let viewModel = PaginatedListViewModel(dependency: dep)
        
        
        XCTAssertEqual(viewModel.items.value, [], "item should be empty initially")
        
        viewModel.loadNextPage()
        
        deliverNextPage(resolveType: .Success)
        
        XCTAssertEqual(viewModel.items.value, ["1", "2"], "item should match first page")
        
        viewModel.loadNextPage()
        deliverNextPage(resolveType: .Success)
        
        XCTAssertEqual(viewModel.items.value, ["1", "2", "3", "4"], "item should match first + second page")
        
        viewModel.reset()
        
        XCTAssertEqual(viewModel.items.value, [], "item should empty after `reset`")
        
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}

struct DynamicPaginatedListViewModelDep: PaginatedListViewModelDependency {
    typealias ListItemType = String
    let firstPageSignal: SignalProducer<RecusrsivePageSignalPayload<String>, NSError>
    
    func intialPageSignal() -> SignalProducer<RecusrsivePageSignalPayload<String>, NSError> {
        return self.firstPageSignal
    }
    
    init(firstPageSignal: SignalProducer<RecusrsivePageSignalPayload<String>, NSError>) {
        self.firstPageSignal = firstPageSignal
    }
}

