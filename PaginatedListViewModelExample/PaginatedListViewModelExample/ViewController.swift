//
//  ViewController.swift
//  PaginatedListViewModelExample
//
//  Created by Sergii Gavryliuk on 2016-03-21.
//  Copyright © 2016 Sergey Gavrilyuk. All rights reserved.
//

import UIKit
import PaginatedListViewModel
import ReactiveCocoa

class ViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    var listViewModel = PaginatedListViewModel(dependency: ListViewModelDependency())
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.listViewModel.items.producer.startWithNext() {[unowned self] _ in
            self.tableView.reloadData()
        }
        
        self.listViewModel.loadNextPage()
    }

}


extension ViewController: UITableViewDataSource {

    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.listViewModel.items.value.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath)
        cell.textLabel?.text = self.listViewModel.items.value[indexPath.row]
        return cell
    }
}

extension ViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(scrollView: UIScrollView) {
        if (scrollView.contentOffset.y > (scrollView.contentSize.height - scrollView.frame.size.height - 10)) {
            self.listViewModel.loadNextPage()
        }
    }
}


struct ListViewModelDependency: PaginatedListViewModelDependency {
    typealias ListItemType = String
    
    
    func intialPageSignal() -> SignalProducer<RecusrsivePageSignalPayload<ListItemType>, NSError> {
        let count = 20
        func makeNextPageSignal(skip: Int) -> SignalProducer<RecusrsivePageSignalPayload<ListItemType>, NSError> {
            return SignalProducer<[[String: AnyObject]], NSError>() {
                sink, disposables in
                
                let session = NSURLSession.sharedSession()
                let task = session.dataTaskWithURL(NSURL(string: "http://jsonplaceholder.typicode.com/comments?_start=\(skip)&_limit=\(count)")!) {
                    data, response, error in
                    if let error = error {
                        sink.sendFailed(error)
                    } else {
                        let json = try! NSJSONSerialization.JSONObjectWithData(data!, options: [])
                        sink.sendNext(json as! [[String: AnyObject]])
                        sink.sendCompleted()
                    }
                }
                disposables += ActionDisposable() { task.cancel() }
                task.resume()
            }
                .map { $0.map { $0["email"] as! String} }
                .map { RecusrsivePageSignalPayload(currentPage: $0, nextPageSignal: makeNextPageSignal(skip + count)) }
        }
        
        return makeNextPageSignal(0)
    }
}

