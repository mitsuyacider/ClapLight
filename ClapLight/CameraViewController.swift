import UIKit
import AVFoundation

@available(iOS 10.0, *)

class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    // カメラの映像をここに表示
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var blendImageView: UIImageView!
    @IBOutlet weak var oneDigits: UIImageView!
    @IBOutlet weak var tenDigits: UIImageView!
    @IBOutlet weak var bgImageView: UIImageView!
    var captureSesssion: AVCaptureSession!
    var stillImageOutput: AVCapturePhotoOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var captureDevice : AVCaptureDevice?
    var imageList : [CIImage] = []
    var timer : Timer?
    var output:AVCaptureVideoDataOutput!
    var myImageOutput: AVCaptureStillImageOutput!
    var enableToKeep = false
    var timeCount = 0
    var isFinished = false
    var blendCIImage : CIImage?
    var beforeCIImage : CIImage?
    var currentUIImage : UIImage?
    var startDate: Date?
    var totalDuration = 0
    
    override var prefersStatusBarHidden: Bool {
        return true
    }

    @IBOutlet weak var imageView: UIImageView!
    @IBAction func tappedExposure(_ sender: UIButton) {
        if let device = captureDevice {
            
            
            do {
                try device.lockForConfiguration()
                
                // Adjust the iso to clamp between minIso and maxIso based on the active format
                let minISO = device.activeFormat.minISO
                let maxISO = device.activeFormat.maxISO
                let clampedISO = minISO
                device.setExposureModeCustomWithDuration(device.activeFormat.maxExposureDuration, iso: clampedISO, completionHandler: { (time) -> Void in
                    //
                })
                
                device.unlockForConfiguration()
                
            } catch {
                // handle error
                return
            }
        }
    }
    
    // ボタンを押した時呼ばれる
    @IBAction func takeIt(_ sender: AnyObject) {
        startTakingPicture()
    }
    
    func startTakingPicture() {
        if (timer != nil && (timer?.isValid)!) {
            timer?.invalidate()
        }
        
        let defaults = UserDefaults.standard
        var duration = defaults.integer(forKey: "time_duration")
        duration = duration < 5 ? 5 : duration
        timeCount = duration
        totalDuration = duration
        
        startDate = Date()
        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.update), userInfo: nil, repeats: true)
        timer?.fire()
        
        
        
        if (!enableToKeep) {
            imageList.removeAll()
            enableToKeep = true
//            blendImageView.image = nil
        }
        
        self.displayCount()
    }
    
    func displayCount() {
        if (timeCount < 0) {
            return
        }
        
        var one : Int = 0
        var ten : Int = 0
        if (timeCount >= 10) {
            one = Int(timeCount % 10)
            ten = Int(timeCount / 10)
            
        } else {
            one = timeCount
            ten = 0
        }
        
        tenDigits.image = UIImage.init(named: "num_" + ten.description + ".png")
        oneDigits.image = UIImage.init(named: "num_" + one.description + ".png")
        
        // Update bg image
        let count = (timeCount % 3) + 1
        let fileName = "start_bg_" + count.description
        bgImageView.image = UIImage.init(named: fileName)
    }
    
    func update(tm: Timer) {
        
        //現在の時間を取得
        let time = NSDate().timeIntervalSince(startDate!)
        let hh = Int(time / 3600)
        let mm = Int((time - Double(hh * 3600)) / 60)
        let ss = Int(time - Double(hh * 3600 + mm * 60))
        
        print(ss)
        timeCount = totalDuration - ss
        
        if (timeCount == 0) {
            bgImageView.image = UIImage.init(named: "end")
            tenDigits.isHidden = true
            oneDigits.isHidden = true
            self.captureSesssion.stopRunning()
        } else {
            self.displayCount()
        }
        
        
        if (timeCount <= -3) {
            generate()
        }
    }
    
    @IBAction func tappedBackButton(_ sender: Any) {
        view.removeFromSuperview()
        removeFromParentViewController()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        captureSesssion = AVCaptureSession()
        stillImageOutput = AVCapturePhotoOutput()
//        stillImageOutput?.isHighResolutionCaptureEnabled = true
//        captureSesssion.sessionPreset = AVCaptureSessionPresetHigh // 解像度の設定
        captureSesssion.sessionPreset = AVCaptureSessionPresetInputPriority
        
        
//        captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        captureDevice = AVCaptureDevice.defaultDevice(
            withDeviceType: .builtInWideAngleCamera,
            mediaType: AVMediaTypeVideo,
            position: .front)


        let defaults = UserDefaults.standard
        let newDurationSeconds = defaults.double(forKey: "shutter_speed")
        
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            
            // 入力
            if (captureSesssion.canAddInput(input)) {
                captureSesssion.addInput(input)
            
                
                
                // AVCaptureVideoDataOutput:動画フレームデータを出力に設定
                output = AVCaptureVideoDataOutput()
                
                // 出力をセッションに追加
                if(captureSesssion.canAddOutput(output)) {
                    captureSesssion.addOutput(output)
                }
                
                // ピクセルフォーマットを 32bit BGR + A とする
                output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable : Int(kCVPixelFormatType_32BGRA)]
                
                // フレームをキャプチャするためのサブスレッド用のシリアルキューを用意
                output.setSampleBufferDelegate(self, queue: DispatchQueue.main)
                
                output.alwaysDiscardsLateVideoFrames = true
                
                captureSesssion.startRunning()
                
                // deviceをロックして設定
                do {
                    try captureDevice?.lockForConfiguration()
                    // フレームレート
                    
                    if (newDurationSeconds == 0) {
                        captureDevice?.activeVideoMinFrameDuration = (captureDevice?.activeVideoMinFrameDuration)!
                        captureDevice?.unlockForConfiguration()
                    } else {
                        let duration = CMTimeGetSeconds( CMTimeMake(1, Int32(Int(1/newDurationSeconds))))
                        let duration2 = CMTimeGetSeconds((captureDevice?.activeVideoMinFrameDuration)!)
                        
                        var result = CMTimeMake(1, Int32(Int(1/newDurationSeconds)))
                        if (duration < duration2) {
                            result = (captureDevice?.activeVideoMinFrameDuration)!
                        }
                        
                        captureDevice?.activeVideoMinFrameDuration = result
                        captureDevice?.unlockForConfiguration()
                        
                    }
                } catch _ {
                }
            }
        }
        catch {
            print(error)
        }
        
        do {
            try captureDevice?.lockForConfiguration()
            
            captureDevice?.exposureMode = AVCaptureExposureMode.custom
            
            // set the camera configuration
            var iso : Float = Float(defaults.integer(forKey: "iso"))
            if((self.captureDevice?.activeFormat.minISO)! > iso) {
                iso = (self.captureDevice?.activeFormat.minISO)!
            } else if ((self.captureDevice?.activeFormat.maxISO)! < iso) {
                iso = (self.captureDevice?.activeFormat.maxISO)!
            }
            
            // exposure
            self.captureDevice?.exposureMode = AVCaptureExposureMode.custom
            if (newDurationSeconds == 0) {
                self.captureDevice?.setExposureModeCustomWithDuration((self.captureDevice?.activeFormat.minExposureDuration)!, iso: Float(iso), completionHandler: nil)
            } else {
                self.captureDevice?.setExposureModeCustomWithDuration(CMTimeMakeWithSeconds( Float64(newDurationSeconds), 1000*1000*1000 ), iso: Float(iso), completionHandler: nil)
            }
            captureDevice?.unlockForConfiguration()
        } catch {
            // handle error
            return
        }
        
        startTakingPicture()
    }
    
    // 新しいキャプチャの追加で呼ばれる
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
       
        autoreleasepool {
            // キャプチャしたsampleBufferからUIImageを作成
            let image:UIImage = self.captureImage(sampleBuffer: sampleBuffer)
            
            // 画像を画面に表示
            let flipImage = flipHorizontal(image: image)
            self.imageView.image = flipImage
            
            if (enableToKeep) {
                if let cimage = CIImage(image: flipImage) {
                    
                    if (beforeCIImage != nil) {
                        let currentCIImage = getBlendCIImage(input1: self.beforeCIImage!, input2: cimage, filter: "CIMaximumCompositing")
                        let context = CIContext(options: nil)
                        let cgImage = context.createCGImage(currentCIImage, from: (currentCIImage.extent))
                        self.blendCIImage = CIImage.init(cgImage: cgImage!)
                    }
                    
                    if (self.blendCIImage != nil) {
                        beforeCIImage = self.blendCIImage
                    } else {
                        beforeCIImage = cimage
                    }
                }
            }
        }
        
    }
    
    func flipHorizontal(image: UIImage) -> UIImage {
        let originalOrientation = image.imageOrientation
        let landscapeImage = UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: .up)
        
        UIGraphicsBeginImageContextWithOptions(landscapeImage.size, false, landscapeImage.scale)
        let context = UIGraphicsGetCurrentContext()
        
        context!.translateBy(x: 0, y: landscapeImage.size.height)
        context!.scaleBy(x: 1.0, y: -1.0)
        
        switch originalOrientation {
        case .up, .upMirrored, .down, .downMirrored:
            context!.translateBy(x: landscapeImage.size.width, y: 0)
            context!.scaleBy(x: -1.0, y: 1.0)
        case .left, .leftMirrored, .right, .rightMirrored:
            context!.translateBy(x: 0, y: landscapeImage.size.height)
            context!.scaleBy(x: 1.0, y: -1.0)
        }
        
        // 画像を描画
        context?.draw(landscapeImage.cgImage!, in: CGRect(origin: CGPoint.zero, size: landscapeImage.size))
        let flipHorizontalImage = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        return UIImage(cgImage: flipHorizontalImage!.cgImage!, scale: flipHorizontalImage!.scale, orientation: originalOrientation)
    }
    
    
    // sampleBufferからUIImageを作成
    func captureImage(sampleBuffer:CMSampleBuffer) -> UIImage{
        
        
        // Sampling Bufferから画像を取得
        let imageBuffer:CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        
        // pixel buffer のベースアドレスをロック
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        let baseAddress:UnsafeMutableRawPointer = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0)!
        
        let bytesPerRow:Int = CVPixelBufferGetBytesPerRow(imageBuffer)
        let width:Int = CVPixelBufferGetWidth(imageBuffer)
        let height:Int = CVPixelBufferGetHeight(imageBuffer)
        
        
        // 色空間
        let colorSpace:CGColorSpace = CGColorSpaceCreateDeviceRGB()
        
        let bitsPerCompornent:Int = 8
        // swift 2.0
        let newContext:CGContext = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: bitsPerCompornent, bytesPerRow: bytesPerRow, space: colorSpace,  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue|CGBitmapInfo.byteOrder32Little.rawValue)!
        
        let imageRef:CGImage = newContext.makeImage()!
        
        let orientation = UIApplication.shared.statusBarOrientation
        var imageOrientation = UIImage().imageOrientation
        if (orientation == UIInterfaceOrientation.landscapeLeft) {
            imageOrientation = UIImageOrientation.up
        } else if(orientation == UIInterfaceOrientation.landscapeRight) {
            imageOrientation = UIImageOrientation.right
        } else {
            imageOrientation = UIImageOrientation.left
        }
        
        let resultImage = UIImage(cgImage: imageRef, scale: 1.0, orientation: imageOrientation)
        CVPixelBufferUnlockBaseAddress(imageBuffer,CVPixelBufferLockFlags(rawValue: 0))
        
        return resultImage
    }
    
    @IBAction func tappedGenerateButton() {
        generate()
    }
    
    func generate() {
        if (timer != nil && (timer?.isValid)!) {
            timer?.invalidate()
        }
        
        // CIImage -> CGImage -> UIImage -> Data
        let context = CIContext(options: nil)
        let cgImage = context.createCGImage(self.blendCIImage!, from: (self.blendCIImage?.extent)!)
        let uiimage = UIImage(cgImage: cgImage!)
        self.blendImageView.image = uiimage
        UIView.animate(withDuration: 1, animations: {
            self.bgImageView.alpha = 0
        }) { (completed) in
            self.enableToKeep = false
            self.isFinished = true
            
            // Save blend image to cameraroll
            UIImageWriteToSavedPhotosAlbum(uiimage, self, #selector(self.finishedSaveing(_:didFinishSavingWithError:contextInfo:)), nil)
        }
    }

    func getBlendCIImage(input1 : CIImage, input2 : CIImage, filter: String) -> CIImage {
        // カラーエフェクトを指定してCIFilterをインスタンス化.
        // @see : http://galakutaapp.blogspot.jp/2016_07_01_archive.html
        
        let myComposeFilter = CIFilter(name: filter)
        // イメージのセット.
        myComposeFilter?.setValue(input1, forKey: kCIInputImageKey)
        myComposeFilter?.setValue(input2, forKey: kCIInputBackgroundImageKey)
        
        // フィルターを通した画像をアウトプット.
        return myComposeFilter!.outputImage!
    }
    
    @IBAction func tappedFilterButton(_ sender: UIButton) {
        /*
        if (timer != nil && (timer?.isValid)!) {
            timer?.invalidate()
        }
        
        
        if imageList.count < 2 {
            return
        }

        print ("filter name = ", (sender.titleLabel?.text)!)
        
        var blendCIImage : CIImage? = getBlendCIImage(input1: imageList[0], input2: imageList[1], filter: (sender.titleLabel?.text)!)
        
        
        for i in 2..<imageList.count {
            if (blendCIImage != nil) {
                let image : CIImage? = getBlendCIImage(input1: imageList[i], input2: blendCIImage!, filter: (sender.titleLabel?.text)!)
                if (image != nil) {
                    blendCIImage = image!
                }
            }
        }
        
        blendImageView.image = UIImage(ciImage: blendCIImage!)
        blendImageView.setNeedsDisplay()
        
        enableToKeep = false
         */

    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if (isFinished) {
            UIView.animate(withDuration: 1, animations: {
                self.view.alpha = 0
            }, completion: { (completed) in
                self.view.removeFromSuperview()
                self.removeFromParentViewController()
            })
        }
        
    }
    
    func finishedSaveing(_ image: UIImage, didFinishSavingWithError error: NSError!, contextInfo: UnsafeMutableRawPointer) {
        
        if error != nil {
            let title = "エラー"
            let message = "保存に失敗しました"
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
}
