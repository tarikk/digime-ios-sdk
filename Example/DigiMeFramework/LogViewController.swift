//
//  LogViewController.swift
//  DigiMeSkeleton
//
//  Created on 20/09/2017.
//  Copyright © 2017 digi.me Ltd. All rights reserved.
//

import Foundation
import UIKit

private let kMALoggingViewDefaultFontSize: CGFloat = 10
private let kMALoggingViewMinFontSize: CGFloat = 2
private let kMALoggingViewMaxFontSize: CGFloat = 28
private let kMALoggingViewDefaultFont = "Courier-Bold"

class LogViewController: UIViewController  {
    var textView: UITextView?
    var currentFontSize: CGFloat = 0.0
    
    // MARK: - View life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        currentFontSize = kMALoggingViewDefaultFontSize
        generateTextView()
        view.backgroundColor = UIColor.black
        edgesForExtendedLayout = []
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Shrink Font", style: .plain, target: self, action: #selector(self.decreaseFontSize))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Grow Font", style: .plain, target: self, action: #selector(self.increaseFontSize))
    }
    
    // MARK: - Navigation button actions
    @objc func increaseFontSize() {
        if currentFontSize >= kMALoggingViewMaxFontSize {
            return
        }
        currentFontSize += 1
        textView?.font = UIFont(name: kMALoggingViewDefaultFont, size: currentFontSize)
    }
    
    @objc func decreaseFontSize() {
        if currentFontSize <= kMALoggingViewMinFontSize {
            return
        }
        currentFontSize -= 1
        textView?.font = UIFont(name: kMALoggingViewDefaultFont, size: currentFontSize)
    }
    
    // MARK: - Text view
    func reset() {
        if textView != nil {
            textView?.removeFromSuperview()
        }
        generateTextView()
    }
    
    func generateTextView() {
        textView = UITextView(frame: view.frame)
        textView?.backgroundColor = UIColor.black
        textView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        textView?.isEditable = false
        textView?.font = UIFont(name: kMALoggingViewDefaultFont, size: currentFontSize)
        textView?.textColor = UIColor.white
        view.addSubview(textView!)
    }
    
    func scrollToBottom() {
        textView?.scrollRangeToVisible(NSRange(location: (textView?.text.characters.count ?? 0), length: 0))
        textView?.isScrollEnabled = false
        textView?.isScrollEnabled = true
    }
    
    // MARK: - Logging
    func log(toView logText: String) {

        if logText == "" {
            return
        }
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let dateString: String = formatter.string(from: now)

        DispatchQueue.main.async(execute: {() -> Void in
            let prevText = (self.textView?.text)!
            self.textView?.text = (prevText + ("\n\(dateString) " + "\(logText) "))

            self.scrollToBottom()
        })

        print("\(logText)")
    }
}
