//
//  ViewController.swift
//  BackgroundRequestsReproductionScenario
//
//  Created by Jaap Mengers on 04/12/2018.
//  Copyright © 2018 Jaap Mengers. All rights reserved.
//

import UIKit

enum ExecutionType {
    case block
    case targetAction
}

enum TaskType {
    case GET
    case POST
    case StreamingPOST
}

//
// MARK: configuration
//
private var nextExecutionType: ExecutionType = .block
private let randomizeExecutionType: Bool = false
//private let url = URL(string: "https://postman-echo.com/delay/1")!
private let taskType: TaskType = .StreamingPOST
let url = URL(string: "http://slowwly.robertomurray.co.uk/delay/1000/url/https://www.google.co.uk")!



/*
 * MARK: NOTES
 *
 * Very reproducible on tasks that take 1+ second using .POST / .block, whether i background quick or slow and whether I wait 1 or 10 seconds
 * Not very reproducible on extremely quick tasks, similar to a ping, using .POST / .block
 *
 *
 */




//
// MARK: URLSession / URLSessionDataTask management
//

class URLOperation: Operation, URLSessionTaskDelegate, URLSessionDelegate, URLSessionDataDelegate {
    var dataTask: URLSessionDataTask? = nil

    var error: Error? = nil

    override func main() {
        if isCancelled {
            return
        }

        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        let dataTask: URLSessionDataTask
        switch taskType {
        case .GET:
            dataTask = createTaskGET(on: session, url: url)
            break

        case .POST:
            dataTask = createTaskPOST(on: session, url: url)
            break

        case .StreamingPOST:
            dataTask = createStreamingTaskPOST(on: session, url: url)
            break
        }

        self.dataTask = dataTask
        dataTask.resume()
        self.isExecuting = true
    }


    func createTaskGET(on session:URLSession, url: URL) -> URLSessionDataTask  {
        // get task, which is idempotent and is buggy
        let dataTask = session.dataTask(with:url)
        return dataTask
    }

    func createTaskPOST(on session:URLSession, url: URL) -> URLSessionDataTask {
        // fails because I cant turn off ATS for some reason
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try! JSONSerialization.data(withJSONObject: [String:Any](), options: [])
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        let dataTask = session.dataTask(with: request)
        return dataTask
    }

    func createStreamingTaskPOST(on session:URLSession, url: URL) -> URLSessionDataTask {
        // empty json object in request body
        let requestOutStream = OutputStream(toMemory: ())
        requestOutStream.open()
        JSONSerialization.writeJSONObject([], to: requestOutStream, options: .prettyPrinted, error: nil)
        requestOutStream.close()
        let data: Data = requestOutStream.property(forKey: .dataWrittenToMemoryStreamKey) as! Data
        let requestInStream = InputStream(data: data)

        // make request
        let request = NSMutableURLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.networkServiceType = .default
        request.httpBodyStream = requestInStream
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("\((requestOutStream.property(forKey: .dataWrittenToMemoryStreamKey) as! Data).count)", forHTTPHeaderField: "Content-Length")

        let dataTask = session.dataTask(with: request as URLRequest)
        return dataTask
    }

    //
    // URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate
    //

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        self.error = error
        self.isFinished = true
        session.finishTasksAndInvalidate()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {

    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {

    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        completionHandler(nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, nil)
    }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, nil)
    }

    //
    // Operation - Executing and finished flags
    //

    var _isFinished: Bool = false
    override var isFinished: Bool {
        get { return _isFinished }
        set {
            willChangeValue(forKey: "isFinished")
            _isFinished = newValue
            didChangeValue(forKey: "isFinished")
        }
    }

    var _isExecuting: Bool = false
    override var isExecuting: Bool {
        get { return _isExecuting }
        set {
            willChangeValue(forKey: "isExecuting")
            _isExecuting = newValue
            didChangeValue(forKey: "isExecuting")
        }
    }
}


//
// MARK: Operation for glueing web requests with Command callbacks
//
class RESTServiceOperation: Operation {
    let command: Command
    init(command: Command) {
        self.command = command
        super.init()
    }

    override func main() {
        let request = URLOperation()
        request.start()
        // prints are to know whether app is suspended on the waitUntilFinished() call without pausing debugger
        print("1")
        request.waitUntilFinished()
        print("2")
        self.finish(withError: request.error)
    }

    func finish(withError error: Error?) {
        self.command.finish(withError: error)
    }
}


//
// MARK: Command - callbacks to caller
//
class Command: NSObject {
    var targetOperationQueue: OperationQueue? = nil
    weak var connection: Connection? = nil

    weak var target: AnyObject? = nil
    var action: Selector? = nil
    var completion: ((AnyObject, Command) -> Void)? = nil

    var error: Error? = nil

    func beginExecute(withTarget target: AnyObject, action: Selector) {
        self.action = action
        sharedExecute(withOwner: target)
    }

    func beginExecute(owner: AnyObject, completion: @escaping (AnyObject, Command) -> Void) {
        self.completion = completion
        sharedExecute(withOwner: owner)
    }

    private func sharedExecute(withOwner owner: AnyObject) {
        guard let connection = connection else { fatalError("Command must have connection") }

        self.targetOperationQueue = OperationQueue.current
        self.target = owner
        connection.queue(command: self)

    }

    func finish(withError error: Error?) {
        if let error = error {
            self.error = error
        }

        guard let targetOperationQueue = targetOperationQueue else { fatalError("Did you forget to store targetOperationQueue") }

        let op = BlockOperation {
            self.completeAndNotify()
        }
        targetOperationQueue.addOperation(op)
    }

    func completeAndNotify() {
        guard let target = self.target else { fatalError("Target deallocated") }

        if let completion = completion {
            completion(target, self)
        } else if let action = action {
            let _ = target.perform(action, with: self)
        } else {
            fatalError("No completion or action")
        }
    }
}


//
// MARK: Connection
//
class Connection: NSObject {
    let operationQueue = OperationQueue()

    override init() {
        operationQueue.maxConcurrentOperationCount = 6
    }

    func queue(command: Command) {
        let op = RESTServiceOperation(command: command)
        operationQueue.addOperation(op)
    }

}

//
// MARK: View Controller - Eexecute commands in loop
//
class ViewController: UIViewController {
    let connection = Connection()

    @IBAction func didTouchButton(_ sender: Any) {
        print("starting")
        self.executeNext()
    }

    func swap(_ type: ExecutionType) -> ExecutionType {
        if type == .block { return .targetAction }
        return .block
    }

    private func executeNext() {
        switch nextExecutionType {
        case .block:
            self.executeCommandBlock()
            break

        case .targetAction:
            self.executeCommandTargetAction()
            break
        }

        // 20% chance to change call type
        if randomizeExecutionType {
            if Int.random(in: 0 ..< 10) < 2 {
                nextExecutionType = swap(nextExecutionType)
            }
        }
    }

    func executeCommandBlock() {
        let command = Command()
        command.connection = self.connection

        command.beginExecute(owner: self) { owner, command in
            guard command.error == nil else {
                print("Aborting")
                return
            }
            print("Block Success")
            let owner = owner as! ViewController
            owner.executeNext()
        }
    }

    func executeCommandTargetAction() {
        let command = Command()
        command.connection = self.connection
        command.beginExecute(withTarget: self, action: #selector(commandFinished(_:)))
    }

    @objc
    private func commandFinished(_ command: Command) {
        guard command.error == nil else {
            print("Aborting")
            return
        }

        print("TA Success")
        self.executeNext()
    }
}
