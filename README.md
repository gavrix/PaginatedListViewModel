# PaginatedListViewModel

[![Build Status](https://travis-ci.org/gavrix/PaginatedListViewModel.svg?branch=master)](https://travis-ci.org/gavrix/PaginatedListViewModel) [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

[`RAC`](https://github.com/ReactiveCocoa/ReactiveCocoa)-based lightweight generic ViewModel to handle paginated lists of items (with pages retrieved asynchronously, typically, but not necessarily,  from from REST APIs)


## Usage

Quick example of how one might use `PaginatedListViewModel`: 

1. Create dependency:
    ```swift
    struct SamplePaginatedListViewModelDependency: PaginatedListViewModelDependency {
        typealias ListItemType = String
        
        func intialPageSignal() -> SignalProducer<RecusrsivePageSignalPayload<ListItemType>, NSError> {
    
            let count = 10
            
            func makeNextPageSignal(skip: Int) -> SignalProducer<RecusrsivePageSignalPayload<ListItemType>, NSError> {
                return SignalProducer() {
                    sink, _ in
                    // make page a list of Ints turned into String
                    let page = (skip...(skip + count)).map{ "\($0)"}
                    
                    let payload = RecusrsivePageSignalPayload(
                        currentPage: page,
                        nextPageSignal: makeNextPageSignal(skip + count)
                    )
                    
                    sink.sendNext(payload)
                    sink.sendCompleted()
                }
            }
            
            return makeNextPageSignal(0)
        }
    }
    ```
2. Create `ViewModel` instance:
    ```swift
    
    let dependency = SamplePaginatedListViewModelDependency()
    let paginatedList = PaginatedListViewModel(dependency: dependency)
    
    ```
3. Observe viewModel's `items` property:
    ```swift
    
    paginatedList.items.producer.startWithNext { items in
        NSLog("Whole list is now \(items)")
    }
    ```
4. Start loading by interacting with ViewModel:
    ```swift
    
    paginatedList.loadNextPage()
    ```

Now, every time you call `loadNextPage` viewModel will ask it's dependency to to request new page through `RAC`'s signals, which will trigger code generating and sending along new page. More on that mechanism below.


## Architecture

`PaginatedListViewModel` is built entirely on [RAC4](https://github.com/ReactiveCocoa/ReactiveCocoa). It relies on the `SignalProducer` as input and outputs information in several properties represented as RAC's `AnyProperty`.

`PaginatedListViewModel` uses dependency injection to abstract away certain specifics of pages are constructed. It's job is to manage list's consistency as well as supporting correct list state (including `loading` and `lastError` properties, which are also observable).

In order to paginate we assume signals requesting next page to be connected. Specifically, we chain them in a recursive manner, using `RecusrsivePageSignalPayload` for indirection. Idea is very simple here: each signal representing page load sends back the payload which is effectively a pair of objects: current page requested plus signalProducer representing following page request. In order to paginate, `PaginatedListViewModel` catches following page's SignalProducer when receiving current page, and next time `loadNextPage()` called it starts that SignalProducer thus kicking off next page's request.

Each time `PaginatedListViewModel` starts next page's SignalProducer property `loading` is set to true, and upon that SignalProducer termination (regardless of success or failure) it is set back to false.

Whenever current page's request fails, SignalProducer representing that page's request is not abandoned. Property `lastError` is set to whatever error was returned from that SignalProducer. Next time `loadNextPage` is called, `PaginatedListViewModel` will attempt to start the same SignalProducer that failed last time. Upon start, `lastError` property is reset to nil.

As one can see, dependency is only used to obtain first page's SignalProducer, as subsequent page's can be obtained from previous page's request. When `reset` method is called in `PaginatedListViewModel`, however, this process is started over and next time `loadNextPage` is called, `PaginatedListViewModel` will request first page's SignalProducer from provided dependency.


## Example project.

Refer to example project in a [collection](https://github.com/gavrix/ViewModelsSamples) of samples for other ViewModel based µ-frameworks [here](https://github.com/gavrix/ViewModelsSamples/blob/master/PaginatedListViewModelExample/README.md).

## Credits

`PaginatedListViewModel` created by Sergey Gavrilyuk [@octogavrix](http://twitter.com/octogavrix).


## License

`PaginatedListViewModel` is distributed under MIT license. See LICENSE for more info.



