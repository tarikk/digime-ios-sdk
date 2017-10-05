//
//  ViewController.swift
//  DigimeSkeleton
//
//  Created on 19/09/2017.
//  Copyright © 2017 digi.me Ltd. All rights reserved.
//

import UIKit
import DigiMeFramework

class ViewController: UIViewController {

    var isLoading: Bool = false
    var loggerController = LogViewController()
    var contractID: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.view.backgroundColor = UIColor.black
        self.title = "digi.me Consent Access"
        initialize()
    }
    
    func initialize() {
        addChildViewController(loggerController)
        self.loggerController.view.frame = view.frame
        self.view.addSubview(loggerController.view)
        self.loggerController.didMove(toParentViewController: self)
        
        DigiMeFramework.sharedInstance().delegate = self
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Start", style: .plain, target: self, action: #selector(addTapped))
        
        self.loggerController.log(toView: "Please press 'Start' to choose one of the available contracts and select it to beging requesting data.")
        self.loggerController.log(toView: "Also make sure that digi.me app is installed and onboarded")
        
        self.navigationController?.isToolbarHidden = false
        var items = [UIBarButtonItem]()
        items.append( UIBarButtonItem(title: "➖", style: .plain, target: self, action: #selector(zoomOut))) // replace add with your function
        items.append( UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil) )
        items.append( UIBarButtonItem(title: "➕", style: .plain, target: self, action: #selector(zoomIn))) // replace add with your function
        self.toolbarItems = items
    }
    
    @objc func zoomIn () {
        self.loggerController.increaseFontSize()
    }
    @objc func zoomOut () {
        self.loggerController.decreaseFontSize()
    }
    
    @objc private func addTapped() {
        let alertView = UIAlertController(title: nil, message: "Choose digi.me Consent Access Contract", preferredStyle: UIScreen.main.traitCollection.userInterfaceIdiom == .pad ? .alert : .actionSheet)
        let contract1Action =  UIAlertAction(title: "All your data from the last 2 years", style: .default, handler: {
            (alert: UIAlertAction!) -> Void in
            self.loggerController.reset()
            self.contractID = staticConstants.kContractID1
            self.requestConsentAccessData(p12FileName: staticConstants.kP12FileName1
                , p12Password: staticConstants.kP12Password
                , privateKeyTag: staticConstants.kPrivateKeyTag)
        })
        
        let contract2Action =  UIAlertAction(title: "All your data from the last 3 months", style: .default, handler: {
            (alert: UIAlertAction!) -> Void in
            self.loggerController.reset()
            self.contractID = staticConstants.kContractID2
            self.requestConsentAccessData(p12FileName: staticConstants.kP12FileName2
                , p12Password: staticConstants.kP12Password
                , privateKeyTag: staticConstants.kPrivateKeyTag)
        })
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: {
            (alert: UIAlertAction!) -> Void in
        })
        
        alertView.addAction(contract1Action)
        alertView.addAction(contract2Action)
        alertView.addAction(cancelAction)
        
        self.present(alertView, animated: true, completion: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    private func requestConsentAccessData(p12FileName: String, p12Password: String, privateKeyTag: String) {
        if(self.isLoading == true) {
            loggerController.log(toView: "Cancelled. The previous request needs to be finished.")
            return
        }
        self.isLoading = true
        let keyHex = SecurityUtilities.getPrivateKeyHex(p12FileName: p12FileName , p12Password: p12Password , privateKeyTag: privateKeyTag)
        DigiMeFramework.sharedInstance().digimeFrameworkInitiateDataRequest(withAppID: staticConstants.kAppID,
                                                                         contractID: self.contractID,
                                                                         rsaPrivateKeyHex:keyHex!)
    }
}

extension ViewController: DigiMeFrameworkDelegate {
    
    func digimeFrameworkLog(withMessage message: String) {
        self.loggerController.log(toView: message)
    }
    
    func digimeFrameworkReceiveData(withFileNames fileNames: [String]?, filesWithContent: [AnyHashable : Any]?, error: Error?) {
        self.isLoading = false
        if(error != nil) {
            self.loggerController.log(toView: String(describing: error))
        } else {
            self.loggerController.log(toView: String(format: "JFS files: %@", fileNames!))
            self.loggerController.log(toView: String(format: "JFS files content: %@", filesWithContent!))
        }
    }
    
    func digimeFrameworkDidChange(_ state: DigiMeFrameworkOperationState) {
        self.loggerController.log(toView: "state: " + String.getDigiMeSDKStateString(state).uppercased())
    }
    
    func digimeFrameworkJsonFilesDownloadProgress(_ progress: Float) {
        self.loggerController.log(toView: String(format: "progress: %.2f%%", progress * 100))
    }
}
