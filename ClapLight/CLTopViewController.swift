//
//  CLTopViewController.swift
//  ClapLight
//
//  Created by Mitstuya.WATANABE on 2017/02/04.
//  Copyright © 2017年 Mitstuya.WATANABE. All rights reserved.
//

import UIKit

class CLTopViewController : UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var countImageView: UIImageView!
    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        countImageView.alpha = 0
        
    }
    
    @IBAction func tappedStartPanel(_ sender: UITapGestureRecognizer) {

        UIView.animate(withDuration: 0.5,
                       // アニメーション中の処理
            animations: { () -> Void in
                                
                self.countImageView.alpha = 1
        }) { (Bool) -> Void in
            self.executeCountDown()
        }
        
    }
    
    func executeCountDown() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // your code here
            self.countImageView.image = UIImage(named: "op_2")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.countImageView.image = UIImage(named: "op_1")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.countImageView.image = UIImage(named: "op_start")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            if #available(iOS 10.0, *) {
                let afterVc : CameraViewController = (self.storyboard?.instantiateViewController(withIdentifier: "CameraViewController")) as! CameraViewController
                self.addChildViewController(afterVc)
                self.view.addSubview(afterVc.view)
                afterVc.didMove(toParentViewController: self)
                self.countImageView.alpha = 0
                self.countImageView.image = UIImage(named: "op_3")
            } else {
                // Fallback on earlier versions
                print("ios 10.0 or earlier")
            }
        }
    }
}
