import UIKit
import AVFoundation

@available(iOS 10.0, *)

class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    // カメラの映像をここに表示
    @IBOutlet weak var cameraView: UIView!
    
    var captureSesssion: AVCaptureSession!
    var stillImageOutput: AVCapturePhotoOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var captureDevice : AVCaptureDevice?
    var imageList : [CIImage] = []
    var timer : Timer?
    
    
    @IBOutlet weak var imageView: UIImageView!
    @IBAction func tappedExposure(_ sender: Any) {
        if let device = captureDevice {
            
            
            do {
                try device.lockForConfiguration()
                device.setFocusModeLockedWithLensPosition(0, completionHandler: { (time) -> Void in
                    //
                })
                
                // Adjust the iso to clamp between minIso and maxIso based on the active format
                let minISO = device.activeFormat.minISO
                let maxISO = device.activeFormat.maxISO
                let clampedISO = minISO
//                print(device.activeFormat.maxExposureDuration)
                print("second: ", device.activeVideoMaxFrameDuration);
                print("second2: ", device.activeFormat.maxExposureDuration);
//                device.activeVideoMaxFrameDuration = CMTimeMakeWithSeconds( 5.0, 1000*1000*1000 )
//                device.activeVideoMaxFrameDuration
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
        imageList.removeAll()
        imageView.image = nil
        if (timer != nil && (timer?.isValid)!) {
            timer?.invalidate()
        }
        timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.update), userInfo: nil, repeats: true)
        timer?.fire()
    }
    
    func update(tm: Timer) {
        // シャッターを切る
        let settingsForMonitoring = AVCapturePhotoSettings()
        settingsForMonitoring.flashMode = .auto
        settingsForMonitoring.isAutoStillImageStabilizationEnabled = true
        settingsForMonitoring.isHighResolutionPhotoEnabled = false
        stillImageOutput?.capturePhoto(with: settingsForMonitoring, delegate: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        // フラッシュとかカメラの細かな設定

        
        captureSesssion = AVCaptureSession()
        stillImageOutput = AVCapturePhotoOutput()
        
        captureSesssion.sessionPreset = AVCaptureSessionPresetInputPriority // 解像度の設定
        
        captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        
        do {
            try captureDevice?.lockForConfiguration()
            captureDevice?.exposureMode = AVCaptureExposureMode.custom
            
//            print(captureDevice?.activeFormat.videoSupportedFrameRateRanges ?? 0)
//            captureDevice?.activeVideoMinFrameDuration  = CMTimeMake(1, 2)
//            captureDevice?.activeVideoMaxFrameDuration  = CMTimeMake( 4, 2 )
            captureDevice?.unlockForConfiguration()
        } catch {
            // handle error
            return
        }

        
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            
            // 入力
            if (captureSesssion.canAddInput(input)) {
                captureSesssion.addInput(input)
                
                // 出力
                if (captureSesssion.canAddOutput(stillImageOutput)) {
                    captureSesssion.addOutput(stillImageOutput)
                    captureSesssion.startRunning() // カメラ起動
                    
                    previewLayer = AVCaptureVideoPreviewLayer(session: captureSesssion)
                    previewLayer?.videoGravity = AVLayerVideoGravityResizeAspect // アスペクトフィット
                    previewLayer?.connection.videoOrientation = AVCaptureVideoOrientation.portrait // カメラの向き
                    
                    cameraView.layer.addSublayer(previewLayer!)
                    
                    // ビューのサイズの調整
                    previewLayer?.position = CGPoint(x: self.cameraView.frame.width / 2, y: self.cameraView.frame.height / 2)
                    previewLayer?.bounds = cameraView.frame
                }
            }
        }
        catch {
            print(error)
        }
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
        if (timer?.isValid)! {
            timer?.invalidate()
        }
        
        if imageList.count < 2 {
            return
        }

        var blendCIImage : CIImage? = getBlendCIImage(input1: imageList[0], input2: imageList[1])
        
        
        for i in 2..<imageList.count {
            if (blendCIImage != nil) {
                let image : CIImage? = getBlendCIImage(input1: imageList[i], input2: blendCIImage!)
                if (image != nil) {
                    blendCIImage = image!
                }
            }
        }
        
        imageView.image = UIImage(ciImage: blendCIImage!)
        imageView.setNeedsDisplay()
    }

    func getBlendCIImage(input1 : CIImage, input2 : CIImage) -> CIImage {
        // カラーエフェクトを指定してCIFilterをインスタンス化.
        let myComposeFilter = CIFilter(name: "CIMaximumCompositing")
        // イメージのセット.
        myComposeFilter?.setValue(input1, forKey: kCIInputImageKey)
        myComposeFilter?.setValue(input2, forKey: kCIInputBackgroundImageKey)
        
        // フィルターを通した画像をアウトプット.
        return myComposeFilter!.outputImage!
    }
}
