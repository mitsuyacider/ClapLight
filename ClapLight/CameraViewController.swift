import UIKit
import AVFoundation

@available(iOS 10.0, *)

class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    // カメラの映像をここに表示
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var blendImageView: UIImageView!
    
    @IBOutlet weak var oneDigits: UIImageView!
    @IBOutlet weak var tenDigits: UIImageView!
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
        
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.update), userInfo: nil, repeats: true)
        timer?.fire()
        
        
        
        if (!enableToKeep) {
            imageList.removeAll()
            enableToKeep = true
            blendImageView.image = nil
        }
        
        self.displayCount()
    }
    
    func displayCount() {
        var one : Int = 0
        var ten : Int = 0
        if (timeCount >= 10) {
            one = Int(timeCount % 10)
            ten = Int(timeCount / 10)
            
        } else {
            one = timeCount
            ten = 0
        }
        
        tenDigits.image = UIImage.init(named: ten.description + ".png")
        oneDigits.image = UIImage.init(named: one.description + ".png")
    }
    
    func update(tm: Timer) {
        // シャッターを切る
        /*
        let settingsForMonitoring = AVCapturePhotoSettings()
        settingsForMonitoring.isAutoStillImageStabilizationEnabled = true
        settingsForMonitoring.isHighResolutionPhotoEnabled = false
        stillImageOutput?.capturePhoto(with: settingsForMonitoring, delegate: self)
        
        */
        
        /*
        // ビデオ出力に接続.
        let myVideoConnection = self.myImageOutput?.connection(withMediaType: AVMediaTypeVideo)
        
        // 接続から画像を取得.
        self.myImageOutput.captureStillImageAsynchronously(from: myVideoConnection, completionHandler: {(imageDataBuffer, error) in
            print("***")
        })
         */
        
        
        timeCount -= 1
        if (timeCount <= 0 ) {
            generate()
        }
        self.displayCount()
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
                
                
                
                /*
                // 出力
                if (captureSesssion.canAddOutput(stillImageOutput)) {
                    captureSesssion.addOutput(stillImageOutput)
                    captureSesssion.startRunning()
                    previewLayer = AVCaptureVideoPreviewLayer(session: captureSesssion)
                    // Fullscreen
                    previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
                    
                    // NOTE: Should let the orientation fit by current orientation
                    previewLayer?.connection.videoOrientation = AVCaptureVideoOrientation.landscapeLeft
                    
                    cameraView.layer.addSublayer(previewLayer!)
                    
                    // Adjust view size
                    previewLayer?.frame.size.width = cameraView.frame.size.width
                    previewLayer?.frame.size.height = cameraView.frame.size.height
                }
                */
                
                /*
                // 出力先を生成.
                myImageOutput = AVCaptureStillImageOutput()
                
                // セッションに追加.
                captureSesssion.addOutput(myImageOutput)
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSesssion)
                // Fullscreen
                previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
                
                // NOTE: Should let the orientation fit by current orientation
                previewLayer?.connection.videoOrientation = AVCaptureVideoOrientation.landscapeLeft
                cameraView.layer.addSublayer(previewLayer!)
                // Adjust view size
                previewLayer?.frame.size.width = cameraView.frame.size.width
                previewLayer?.frame.size.height = cameraView.frame.size.height
                captureSesssion.startRunning()
                */
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
        
        // キャプチャしたsampleBufferからUIImageを作成
        let image:UIImage = self.captureImage(sampleBuffer: sampleBuffer)

        // 画像を画面に表示
        self.imageView.image = image
        
        if (enableToKeep) {
            if let cimage = CIImage(image: image) {
                imageList.append(cimage)
            }
        }
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
        let resultImage = UIImage(cgImage: imageRef, scale: 1.0, orientation: UIImageOrientation.up)
        
        return resultImage
    }
    
    
    // デリゲート。カメラで撮影が完了した後呼ばれる。JPEG形式でフォトライブラリに保存。
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        
        if let photoSampleBuffer = photoSampleBuffer {
            // JPEG形式で画像データを取得
            let photoData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer)
            let image : UIImage? = UIImage(data: photoData!)
            
            if let cimage = CIImage(image: image!) {
                imageList.append(cimage)
            }
        }
    }
    
    @IBAction func tappedGenerateButton() {
        generate()
    }
    
    func generate() {
        if (timer != nil && (timer?.isValid)!) {
            timer?.invalidate()
        }
        
        if imageList.count < 2 {
            return
        }
        
        var blendCIImage : CIImage? = getBlendCIImage(input1: imageList[0], input2: imageList[1], filter: "CIMaximumCompositing")
        
        
        for i in 2..<imageList.count {
            if (blendCIImage != nil) {
                let image : CIImage? = getBlendCIImage(input1: imageList[i], input2: blendCIImage!, filter: "CIMaximumCompositing")
                if (image != nil) {
                    blendCIImage = image!
                }
            }
        }
        
        blendImageView.image = UIImage(ciImage: blendCIImage!)
        blendImageView.setNeedsDisplay()
        
        enableToKeep = false
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

    }
    
}
