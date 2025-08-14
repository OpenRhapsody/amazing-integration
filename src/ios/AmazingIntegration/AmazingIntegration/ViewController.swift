//
//  ViewController.swift
//  AmazingIntegration
//
//  Created by Leo Kim on 8/14/25.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBAction func tapOpenAmazingQuest(_ sender: Any) {
        guard let url = URL(string: "https://quest.adrop.io/example-channel") else {
            return
        }
        let amazingQuestViewController = AmazingWebViewController(url: url)
        present(amazingQuestViewController, animated: true)
    }
}

