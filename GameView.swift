import Foundation
import UIKit
import CoreGraphics
import CoreText
import AudioToolbox

let ButtonDown: [Int32] = [Int32(LEFT_BUTTON),  Int32(RIGHT_BUTTON),  Int32(MIDDLE_BUTTON)]
let ButtonDrag: [Int32] = [Int32(LEFT_DRAG),    Int32(RIGHT_DRAG),    Int32(MIDDLE_DRAG)]
let ButtonUp: [Int32]   = [Int32(LEFT_RELEASE), Int32(RIGHT_RELEASE), Int32(MIDDLE_RELEASE)]

let NBUTTONS = 10;

typealias VoidPtr = UnsafeMutableRawPointer?
typealias ConstVoidPtr = UnsafeRawPointer?
typealias CharPtr = UnsafeMutablePointer<Int8>?
typealias ConstCharPtr = UnsafePointer<Int8>?
typealias Int32Ptr = UnsafeMutablePointer<Int32>?
typealias ConstInt32Ptr = UnsafePointer<Int32>?
typealias ConstCharPtrConstPtr = UnsafePointer<ConstCharPtr>?

func bridge<T : AnyObject>(obj : T) -> UnsafeMutableRawPointer {
    return UnsafeMutableRawPointer(Unmanaged.passUnretained(obj).toOpaque())
}

func bridge<T : AnyObject>(ptr : UnsafeMutableRawPointer) -> T {
    return Unmanaged<T>.fromOpaque(ptr).takeUnretainedValue()
}


class GameView : UIView, GameSettingsDelegate {
    var nc: UINavigationController
    var theGame: UnsafeMutablePointer<game>
    var midend: OpaquePointer!
    var fe: frontend = frontend(gv: nil, colours: nil, ncolours: 0, clipping: false, activate_timer: {fe in attach_timer(fe: fe!)}, deactivate_timer: {fe in detach_timer(fe: fe!)})
    var usableFrame: CGRect!
    var gameRect: CGRect!
    var timer: Timer!
    var gameToolbar: UIToolbar? = nil
    var touchState: Int = 0
    var touchXPoints: Int32 = 0
    var touchYPoints: Int32 = 0
    var touchXPixels: Int32 = 0
    var touchYPizels: Int32 = 0
    var touchButton: Int = 0
    var touchTimer: Timer? = nil
    var toolbar: UIToolbar?
    var buttons: Dictionary<String, UIBarButtonItem> = Dictionary<String, UIBarButtonItem>()
    var statusbar: UILabel?
    var bitmap: CGContext?
    var blitter: Blitter?
 
    init(nc:UINavigationController, game: UnsafeMutablePointer<game>, saved:String?, inProgess:Bool, frame:CGRect) {
        self.nc = nc
        theGame = game
        super.init(frame: frame)
        fe.gv = bridge(obj: self)
            
        // Set the environment to set the preferred tile size...
        let key = "\(String(cString: theGame.pointee.name).uppercased().replacingOccurrences(of: " ", with: ""))_TILESIZE"
        let value = "\(theGame.pointee.preferred_tilesize * 4)"
        setenv(key, value, 1)
        
        midend = midend_new(&fe, theGame, &swift_drawing_api, bridge(obj: self));
        fe.colours = midend_colours(midend, &fe.ncolours);
        self.backgroundColor = UIColor.init(red: CGFloat(fe.colours![0]), green: CGFloat(fe.colours![1]), blue: CGFloat(fe.colours![2]), alpha: 1)
        if (saved != nil) {
            var ctx = StringReadConext(save: saved!, position: 0)
            let msg = midend_deserialise(midend, {ctx, buffer, length in saveGameRead(ctx: ctx, buffer: buffer, length: length)}, bridge(obj: ctx))
            if (msg != nil) {
                let alert = UIAlertController(title: "Puzzles", message: String(cString: msg!), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                nc.present(alert, animated: false, completion: nil)
                startNewGame()
            } else if (!inProgess) {
                startNewGame()
            }
        } else {
            if (theGame == pattern_ptr && traitCollection.horizontalSizeClass == .compact || traitCollection.verticalSizeClass == .compact) {
                midend_game_id(midend, "S")
            }
            startNewGame()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if (midend != nil) {
            midend_free(midend);
        }
    }
    
    fileprivate func netCentreMode() -> Bool {
        return (theGame == net_ptr) && buttons["Centre"]?.style == .done
    }
    
    fileprivate func netShiftMode() -> Bool {
        return (theGame == net_ptr) && buttons["Shift"]?.style == .done
    }
    
    func startNewGame() {
        let m: OpaquePointer = self.midend
        let window: UIWindow = UIApplication.shared.windows[0]
        
        // Create a clear overlau to consume touches during puzzle generation
        let overlay: UIView = UIView.init(frame: window.rootViewController!.view.bounds)
        window.rootViewController!.view.addSubview(overlay)
        
        let (box, aiv) = createProgressIndicator(overlay: overlay)
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(250)) {
            box.isHidden = false
        }
        
        DispatchQueue.global().async {
            midend_new_game(m)
            DispatchQueue.main.async {
                aiv.stopAnimating()
                overlay.removeFromSuperview()
                self.midend = m
                self.layoutSubviews()
            }
        }
    }
    
    fileprivate func createProgressIndicator(overlay: UIView) -> (UIView, UIActivityIndicatorView) {
        let box = UIView(frame: CGRect(x: (overlay.bounds.width - 200) / 2, y: (overlay.bounds.height - 50) / 2, width: 200, height: 50))
        box.backgroundColor = UIColor.black
        box.isHidden = true
        overlay.addSubview(box)
        
        let aiv = UIActivityIndicatorView(style: .whiteLarge)
        let inset = (box.bounds.height - aiv.bounds.height) / 2
        aiv.frame = CGRect(x: inset, y: inset, width: aiv.bounds.width, height: aiv.bounds.height)
        box.addSubview(aiv)
        
        let label = UILabel(frame: CGRect(x: inset * 2 + aiv.bounds.width, y: (box.bounds.height - 20 ) / 2, width: box.frame.width - inset * 2 - aiv.bounds.width, height: 20))
        label.backgroundColor = UIColor.black
        label.textColor = UIColor.white
        label.text = "Generating puzzle"
        box.addSubview(label)
        
        aiv.startAnimating()
        
        return (box, aiv)
    }
    
    fileprivate func buildToolbar(r: CGRect) {
        if (toolbar != nil) {
            toolbar!.frame = r
        } else {
            toolbar = UIToolbar(frame: r)
            let items = [
                UIBarButtonItem(title: "Game", style: .plain, target: self, action: #selector(doGameMenu)),
                UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                UIBarButtonItem(barButtonSystemItem: .undo,  target: self, action: #selector(doUndo)),
                UIBarButtonItem(barButtonSystemItem: .redo, target: self, action: #selector(doRedo)),
                UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                UIBarButtonItem(title: "Type", style: .plain, target: self,    action: #selector(doType)),
            ]
            toolbar!.setItems(items, animated: false)
            addSubview(toolbar!)
        }
    }
    
    fileprivate func buildStatusBar(topMargin: CGFloat, usableHeight: inout CGFloat) {
        if (midend_wants_statusbar(midend)) {
            usableHeight -= 20
            let r = CGRect(x: 0, y: topMargin + usableHeight, width: self.frame.width, height: 20)
            if (self.statusbar != nil) {
                self.statusbar!.frame = r
            } else {
                self.statusbar = UILabel(frame: r)
                self.addSubview(self.statusbar!)
            }
        } else {
            self.statusbar?.removeFromSuperview()
            self.statusbar = nil
        }
    }
    
    fileprivate func buildGameButtons(toolbarHeight: CGFloat, topMargin: CGFloat, usableHeight: inout CGFloat) {
        buttons.removeAll()
        if (theGame == filling_ptr
         || theGame == keen_ptr
         || theGame == map_ptr
         || theGame == net_ptr
         || theGame == solo_ptr
         || theGame == towers_ptr
         || theGame == undead_ptr
         || theGame == unequal_ptr) {
            usableHeight -= toolbarHeight;
            var main_button_count = 9;
            var extra_button_count = 0;
            var labels: [String]? = nil;
            var extra_labels: [String] = [];
            if (theGame == filling_ptr) {
                let fillingLabels = ["0"];
                extra_labels = fillingLabels
                extra_button_count = 1;
            } else if (theGame == keen_ptr) {
                let keenLabels = ["Marks"]
                main_button_count = Int(String(cString: midend_get_game_id(midend)))!;
                extra_labels = keenLabels;
                extra_button_count = 1;
            } else if (theGame == map_ptr) {
                let mapLabels = ["Labels"]
                main_button_count = 1;
                labels = mapLabels;
            } else if (theGame == net_ptr) {
                let netLabels = ["Jumble", "Centre", "Shift"]
                main_button_count = 0;
                extra_labels = netLabels;
                extra_button_count = 2;
                // Shift only applies to wrapping games
                if ((strstr(midend_get_game_id(midend), "w:")) != nil) {
                    extra_button_count = 3;
                }
            } else if (theGame == solo_ptr) {
                let game_id = String(cString: midend_get_game_id(midend))
                let scanner: Scanner = Scanner(string: game_id)
                var x: Int = 0
                var y: Int = 0
                let gotX = scanner.scanInt(UnsafeMutablePointer<Int>(&x))
                _ = scanner.scanUpTo("x", into: nil)
                let gotY = scanner.scanInt(UnsafeMutablePointer<Int>(&y))
                
                if (gotX && gotY) {
                    main_button_count = x * y;
                }
            } else if (theGame == towers_ptr) {
                let towersLabels = ["Marks"];
                main_button_count = Int(String(cString: midend_get_game_id(midend)))!
                extra_labels = towersLabels;
                extra_button_count = 1;
            } else if (theGame == undead_ptr) {
                let undeadLabels = ["Ghost", "Vampire", "Zombie"]
                main_button_count = 3;
                labels = undeadLabels;
            } else if (theGame == unequal_ptr) {
                let unequalLabels = ["Marks", "Hints"];
                main_button_count = Int(String(cString: midend_get_game_id(midend)))!;
                extra_labels = unequalLabels;
                extra_button_count = 2;
            }
            let r = CGRect(x: 0, y: topMargin + usableHeight, width: self.frame.width, height: toolbarHeight)
            if (gameToolbar == nil) {
                gameToolbar = UIToolbar(frame: r)
            } else {
                gameToolbar?.frame = r
            }
            var items: Array<UIBarButtonItem> = Array()
            items.append(UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil))
            items.append(UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil))
            for i in 0..<(main_button_count + extra_button_count) {
                let title: String
                if (i < main_button_count) {
                    if (labels != nil) {
                        title = labels![i]
                    } else if (i < 9) {
                        title = String(i + 1)
                    } else {
                        title = String(format: "%x", i)
                    }
                } else {
                    title = extra_labels[i - main_button_count]
                }
                let button = UIBarButtonItem(title: title, style: .plain, target: self, action: #selector(keyButton))
                items.append(button)
                buttons[title] = button
                items.append(UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil))
            }
            items.append(UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil))
            gameToolbar!.items = items
            addSubview(gameToolbar!)
        } else {
            gameToolbar?.removeFromSuperview()
            gameToolbar = nil
        }
    }
    
    override func draw(_ rect: CGRect) {
        if (midend == nil) {
            return
        } else {
            let context = UIGraphicsGetCurrentContext()
            let image = bitmap?.makeImage()
            if (image != nil) {
                context?.draw(image!, in: gameRect)
            }
        }
    }
    
    fileprivate func adjustDragPosition(x: inout Int32, y: inout Int32) {
        if (theGame == untangle_ptr) {
            let ts = midend_tilesize(midend)
            x = max(ts/8, x)
            x = min(Int32(gameRect.width*contentScaleFactor / 8 - 1), x)
            y = max(ts/8, y)
            y = min(Int32(gameRect.height*contentScaleFactor / 8 - 1), y)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first
        var p = touch!.location(in: self)
        p.x -= gameRect.origin.x
        p.y -= gameRect.origin.y
        touchTimer = Timer(timeInterval: TimeInterval(0.5), target: self, selector: #selector(handleTouchTimer), userInfo: nil, repeats: false)
        RunLoop.current.add(touchTimer!, forMode: RunLoop.Mode.default)
        touchState = 1
        touchXPoints = Int32(p.x)
        touchYPoints = Int32(p.y)
        touchXPixels = Int32(p.x * contentScaleFactor)
        touchYPizels = Int32(p.y * contentScaleFactor)
        adjustDragPosition(x: &touchXPixels, y: &touchYPizels)
        touchButton = 0
        if (netCentreMode()) {
            midend_process_key(midend, touchXPixels, touchYPizels, 0x03)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first
        var p = touch!.location(in: self)
        p.x -= gameRect.origin.x
        p.y -= gameRect.origin.y
        let xPoints: Int32 = Int32(min(gameRect.width - 1, max(p.x, 0)))
        let yPoints: Int32 = Int32(min(gameRect.height - 1, max(p.y, 0)))
        var xPixels = xPoints * Int32(contentScaleFactor)
        var yPixels = yPoints * Int32(contentScaleFactor)
        adjustDragPosition(x: &xPixels, y: &yPixels)
        if (netCentreMode()) {
            midend_process_key(midend, xPixels, yPixels, 0x03)
        } else if (netShiftMode()) {
            let ts = midend_tilesize(midend)
            while (touchXPixels <= xPixels - ts) {
                midend_process_key(midend, -1, -1, Int32(MOD_SHFT | CURSOR_LEFT))
                touchXPixels -= ts
            }
            while (touchXPixels >= xPixels - ts) {
                midend_process_key(midend, -1, -1, Int32(MOD_SHFT | CURSOR_RIGHT))
                touchXPixels += ts
            }
            while (touchYPizels <= yPixels - ts) {
                midend_process_key(midend, -1, -1, Int32(MOD_SHFT | CURSOR_UP))
                touchYPizels -= ts
            }
            while (touchYPizels >= yPixels - ts) {
                midend_process_key(midend, -1, -1, Int32(MOD_SHFT | CURSOR_DOWN))
                touchYPizels += ts
            }
        } else {
            if (touchState == 1) {
                if (abs(xPoints + touchXPoints) >= 20 || abs(yPoints + touchYPoints) >= 20) {
                    touchTimer?.invalidate()
                    touchTimer = nil
                    midend_process_key(midend, touchXPixels, touchYPizels, ButtonDown[touchButton]);
                    touchState = 2;
                }
            }
            if (touchState == 2) {
                midend_process_key(midend, xPixels, yPixels, ButtonDrag[touchButton])
            }
        }

    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first
        var p = touch!.location(in: self)
        p.x -= gameRect.origin.x
        p.y -= gameRect.origin.y
        let xPoints: Int32 = Int32(min(gameRect.width - 1, max(p.x, 0)))
        let yPoints: Int32 = Int32(min(gameRect.height - 1, max(p.y, 0)))
        var xPixels = xPoints * Int32(contentScaleFactor)
        var yPixels = yPoints * Int32(contentScaleFactor)
        adjustDragPosition(x: &xPixels, y: &yPixels)
        if (netCentreMode() || netShiftMode()) {
            return
        } else {
            if (touchState == 1) {
                midend_process_key(midend, touchXPixels, touchYPizels, ButtonDown[touchButton])
            }
            midend_process_key(midend, touchXPixels, touchYPizels, ButtonUp[touchButton])
        }
        touchState = 0
        touchTimer?.invalidate()
        touchTimer = nil
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchState = 0
        touchTimer?.invalidate()
        touchTimer = nil
    }
    
    @objc func handleTouchTimer(timer: Timer) {
        if (netCentreMode() || netShiftMode()) {
            return
        } else {
            if (theGame == net_ptr) {
                touchButton = 2
            } else {
                touchButton = 1
            }
            midend_process_key(midend, touchXPixels, touchYPizels, ButtonDown[touchButton])
            touchState = 2
            UIDevice.current.playInputClick()
        }
    }
    
    @objc func keyButton(sender: UIBarButtonItem) {
        if (theGame == net_ptr) {
            if (sender == buttons["Centre"]) {
                if (netCentreMode()) {
                    sender.style = .plain
                } else {
                    sender.style = .done
                    buttons["Shift"]?.style = .plain
                }
                return
            } else if (sender == buttons["Shift"]) {
                if (netShiftMode()) {
                    sender.style = .plain
                } else {
                    sender.style = .done
                    buttons["Centre"]?.style = .plain
                }
                return

            }
        }
        let key = Array(sender.title!)[0]
        midend_process_key(midend, -1, -1, Int32(key.asciiValue!))
    }
    
    func activateTimer() {
        timer?.invalidate()
        timer = Timer(timeInterval: TimeInterval(0.02), target: self, selector: #selector(timerFire), userInfo: nil, repeats: true)
        RunLoop.current.add(timer!, forMode: .default)
    }
    
    func deactivateTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    @objc func timerFire(timer: Timer) {
        if (midend != nil) {
            midend_timer(midend, Float(timer.timeInterval))
        }
    }
    
    func drawGameRect(rect: CGRect) {
        let r = CGRect(x: rect.origin.x/contentScaleFactor, y: rect.origin.y/contentScaleFactor, width: rect.width/contentScaleFactor, height: rect.height/contentScaleFactor).offsetBy(dx: gameRect.origin.x, dy: gameRect.origin.y)
        setNeedsDisplay(r)
    }
    
    func saveGame(inProgress: inout Bool) -> String? {
        if (midend == nil) {
            return nil
        }
        
        inProgress = midend_can_undo(midend) && midend_status(midend) == 0
        let save = NSMutableString()
        midend_serialise(midend, {ctx, buffer, length in saveGameWrite(ctx: ctx, buffer: buffer, length: length)}, bridge(obj: save))
        return String(save)
    }
    
    override func layoutSubviews() {
        if (self.midend == nil) {
            return
        }
        let toolbarHeight: CGFloat = self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClass.compact ? 32 : 44
        let topMargin: CGFloat = 0
        var usableHeight = self.frame.height - toolbarHeight - topMargin
        
        let r: CGRect = CGRect(x: 0, y: topMargin + usableHeight, width: self.frame.width, height: toolbarHeight)
        
        buildToolbar(r: r)
        buildStatusBar(topMargin: topMargin, usableHeight: &usableHeight)
        buildGameButtons(toolbarHeight: toolbarHeight, topMargin: topMargin, usableHeight: &usableHeight)
        usableFrame = CGRect(x: 0, y: topMargin, width: self.frame.width, height: usableHeight)
        let fw = Int32(frame.width * contentScaleFactor)
        let fh = Int32(usableHeight * contentScaleFactor)
        var w = fw
        var h = fh
        midend_size(midend, &w, &h, false)
        
        gameRect = CGRect(x: CGFloat(fw - w)/2/contentScaleFactor, y: CGFloat(fh - h)/2/contentScaleFactor, width: CGFloat(w)/contentScaleFactor, height: CGFloat(h)/contentScaleFactor)
        gameRect.origin.y += topMargin
        let cs = CGColorSpaceCreateDeviceRGB()
        bitmap = CGContext(data: nil, width: Int(w), height: Int(h), bitsPerComponent: 8, bytesPerRow: Int(w)*4, space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        midend_force_redraw(midend)
        setNeedsDisplay()
    }
    
    @objc func doGameMenu() {
        let gameMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        gameMenu.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: {_ in }))
        gameMenu.addAction(UIAlertAction(title: "New Game", style: .destructive, handler: {_ in self.startNewGame() }))
        gameMenu.addAction(UIAlertAction(title: "Specific Game", style: .default, handler: {_ in self.doSpecificGame() }))
        gameMenu.addAction(UIAlertAction(title: "Specific Random Seed", style: .default, handler: {_ in self.doSpecificSeed() }))
        gameMenu.addAction(UIAlertAction(title: "Restart", style: .default, handler: {_ in self.doRestart() }))
        gameMenu.addAction(UIAlertAction(title: "Solve", style: .default, handler: {_ in self.doSolve() }))
        
        let pop = gameMenu.popoverPresentationController
        pop?.barButtonItem = toolbar!.items![0]
        nc.present(gameMenu, animated: true, completion: nil)
    }
    
    func doSpecificGame() {
        var winTitle: CharPtr = nil
        let config = midend_get_config(midend, Int32(CFG_DESC), &winTitle)
        nc.pushViewController(GameSettingsController(game: theGame, config_items: config!, type: CFG_DESC, title: String(cString: winTitle!), delegate: self), animated: true)
        free(winTitle)
    }
    
    func doSpecificSeed() {
        var winTitle: CharPtr = nil
        let config = midend_get_config(midend, Int32(CFG_SEED), &winTitle)
        nc.pushViewController(GameSettingsController(game: theGame, config_items: config!, type: CFG_SEED, title: String(cString: winTitle!), delegate: self), animated: true)
        free(winTitle)
    }
    
    func didApply(config: UnsafeMutablePointer<config_item>) {
        let msg = midend_game_id(midend, config[0].name)
        if (msg != nil) {
            let alert = UIAlertController(title: "Puzzles", message: String(cString: msg!), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Close", style: .cancel, handler: nil))
            nc.present(alert, animated: false, completion: nil)
        }
        startNewGame()
        nc.popViewController(animated: true)
    }
    
    @objc func doUndo() {
        midend_process_key(midend, -1, -1, Int32(Character("u").asciiValue!));
    }
    
    @objc func doRedo() {
        midend_process_key(midend, -1, -1, Int32(Character("r").asciiValue!)&0x1F);
    }
    
    func doRestart() {
        midend_restart_game(midend)
    }

    func doSolve() {
        let msg = midend_solve(midend)
        if (msg != nil) {
            let alert = UIAlertController(title: "PUzzles", message: String(cString: msg!), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Close", style: .cancel, handler: nil))
            nc.present(alert, animated: false, completion: nil)
        }
    }
    
    @objc func doType() {
        nc.pushViewController(GameTypeController(game: theGame, midend: midend, gameView: self), animated: true)
    }
    
    func didApply(item: UnsafeMutablePointer<config_item>) {
        let msg = midend_game_id(midend, item[0].name)
        if (msg != nil) {
            let alert = UIAlertController(title: "Puzzles", message: String(cString: msg!), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            nc.present(alert, animated: false, completion: nil)
            return
        }
        startNewGame()
        nc.popToRootViewController(animated: true)
    }
}

fileprivate func saveGameWrite(ctx: VoidPtr, buffer: ConstVoidPtr, length: Int32) -> Void {
    let str: NSMutableString = bridge(ptr: ctx!)
    str.append(String.init(bytesNoCopy: UnsafeMutableRawPointer(mutating: buffer!), length: Int(length), encoding: .utf8, freeWhenDone: false)!)
}

fileprivate class StringReadConext {
    let data: [UInt8]
    var position: Int
    
    init(save: String, position: Int) {
        self.position = position
        data = Array(save.data(using: .utf8)!)
    }
}

fileprivate func saveGameRead(ctx: VoidPtr, buffer: VoidPtr, length: Int32) -> Bool {
    let srctx: StringReadConext = bridge(ptr: ctx!)
    let ptr = UnsafeMutablePointer<UInt8>(OpaquePointer(buffer))
    let bufPtr = UnsafeMutableBufferPointer<UInt8>(start: ptr, count: Int(length))
    srctx.data.copyBytes(to: bufPtr, from: srctx.position..<(srctx.position + Int(length)))
    srctx.position += Int(length)
    return true
}

let swift_draw_text: (@convention(c) (VoidPtr, Int32, Int32, Int32, Int32, Int32, Int32, ConstCharPtr) -> Void)? = { handle, x, y, fontType, fontSize, align, colour, text in drawText(handle: handle, x: x, y: y, fontType: fontType, fontSize: fontSize, align: align, colour: colour, text: text)}

let swift_draw_rect: (@convention(c) (VoidPtr, Int32, Int32, Int32, Int32, Int32) -> Void) = { handle, x, y, w, h, colour in drawRect(handle: handle, x: x, y: y, w: w, h: h, colour: colour)}
let swift_draw_line: (@convention(c) (VoidPtr, Int32, Int32, Int32, Int32, Int32) -> Void) = { handle, x, y, x2, y2, colour in drawLine(handle: handle, x: x, y: y, x2: x2, y2: y2, colour: colour)}
let swift_draw_polygon: (@convention(c) (VoidPtr, Int32Ptr, Int32, Int32, Int32) -> Void) = {handle, coords, npoints, fillColour, outlineColour in drawPolygon(handle: handle, coords: coords, npoints: npoints, fillcolour: fillColour, outlinecolour: outlineColour)}
let swift_draw_circle: (@convention(c) (VoidPtr, Int32, Int32, Int32, Int32, Int32) -> Void) = {handle, cx, cy, radius, fillColour, outlineColour in drawCircle(handle: handle, cx: cx, cy: cy, radius: radius, fillcolour: fillColour, outlinecolour: outlineColour)}
let swift_draw_update: (@convention(c) (VoidPtr, Int32, Int32, Int32, Int32) -> Void) = {handle, x, y, w, h in drawUpdate(handle: handle, x: x, y: y, w: w, h: h)}
let swift_clip: (@convention(c) (VoidPtr, Int32, Int32, Int32, Int32) -> Void) = {handle, x, y, w, h in clip(handle: handle, x: x, y: y, w: w, h: h)}
let swift_unclip: (@convention(c) (VoidPtr) -> Void) = {handle in unclip(handle: handle)}
let swift_start_draw: (@convention(c) (VoidPtr) -> Void) = {handle in startDraw(handle: handle)}
let swift_end_draw: (@convention(c) (VoidPtr) -> Void) = {handle in endDraw(handle: handle)}
let swift_statusbar: (@convention(c) (VoidPtr, ConstCharPtr) -> Void) = {handle, text in statusBar(handle: handle, text: text)}
let swift_blitter_new: (@convention(c) (VoidPtr, Int32, Int32) -> OpaquePointer?) = { handle, w, h in blitterNew(handle: handle, w: w, h: h)}
let swift_blitter_free: (@convention(c) (VoidPtr, OpaquePointer?) -> Void) = { handle, blitter in blitterFree(handle: handle, blitter: blitter)}
let swift_blitter_save:  (@convention(c) (VoidPtr, OpaquePointer?, Int32, Int32) -> Void) = { handle, blitter, x, y in blitterSave(handle: handle, blitter: blitter, x: x, y: y)}
let swift_blitter_load:  (@convention(c) (VoidPtr, OpaquePointer?, Int32, Int32) -> Void) = { handle, blitter, x, y in blitterLoad(handle: handle, blitter: blitter, x: x, y: y)}
let swift_text_fallback: (@convention(c) (VoidPtr, ConstCharPtrConstPtr, Int32) -> CharPtr) = { handle, strings, nStrings in textFallback(handle: handle, strings: strings, nStrings: nStrings)}

var swift_drawing_api: drawing_api = drawing_api(
    draw_text: swift_draw_text,
    draw_rect: swift_draw_rect,
    draw_line: swift_draw_line,
    draw_polygon: swift_draw_polygon,
    draw_circle: swift_draw_circle,
    draw_update: swift_draw_update,
    clip: swift_clip,
    unclip: swift_unclip,
    start_draw: swift_start_draw,
    end_draw: swift_end_draw,
    status_bar: swift_statusbar,
    blitter_new: swift_blitter_new,
    blitter_free: swift_blitter_free,
    blitter_save: swift_blitter_save,
    blitter_load: swift_blitter_load,
    begin_doc: nil,
    begin_page: nil,
    begin_puzzle: nil,
    end_puzzle: nil,
    end_page: nil,
    end_doc: nil,
    line_width: nil,
    line_dotted: nil,
    text_fallback: swift_text_fallback,
    draw_thick_line: nil)

fileprivate func getGV(handle: VoidPtr) -> GameView {
    return bridge(ptr: UnsafeMutableRawPointer(OpaquePointer(handle))!)
}
fileprivate func rgb(gv: GameView, colour: Int32) -> [CGFloat] {
    return [CGFloat(gv.fe.colours![Int(colour) * 3 + 0]),
            CGFloat(gv.fe.colours![Int(colour) * 3 + 1]),
            CGFloat(gv.fe.colours![Int(colour) * 3 + 2])]
}
fileprivate func drawText(handle: VoidPtr, x: Int32, y: Int32, fontType: Int32, fontSize: Int32, align: Int32, colour: Int32, text: ConstCharPtr?) -> Void {
    let gv = getGV(handle: handle)
    let str = String(cString: text!!)
    let font = CTFontCreateWithName("Helvetica" as CFString, CGFloat(fontSize), nil)
    let cs = CGColorSpaceCreateDeviceRGB()
    let comps: [CGFloat] = rgb(gv: gv, colour: colour)
    let colour = CGColor(colorSpace: cs, components: comps)
    let attributes: Dictionary<CFString, Any?> = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: colour]
    let attrStr = CFAttributedStringCreate(nil, str as CFString, attributes as CFDictionary)
    let line = CTLineCreateWithAttributedString(attrStr!)
    gv.bitmap!.textMatrix = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0)
    let width = CTLineGetOffsetForStringIndex(line, CFAttributedStringGetLength(attrStr), nil)
    var tx = CGFloat(x)
    var ty = CGFloat(y)
    switch (align & (ALIGN_HLEFT|ALIGN_HCENTRE|ALIGN_HRIGHT)) {
        case ALIGN_HLEFT:
            break;
        case ALIGN_HCENTRE:
            tx -= width / 2;
            break;
        case ALIGN_HRIGHT:
            tx -= width;
            break;
    default: break
    }
    switch (align & (ALIGN_VNORMAL|ALIGN_VCENTRE)) {
        case ALIGN_VNORMAL:
            break;
        case ALIGN_VCENTRE:
            ty += CGFloat(fontSize) * 0.4;
            break;
    default: break
    }
    gv.bitmap!.textPosition = CGPoint(x: tx, y: ty)
    CTLineDraw(line, gv.bitmap!);
}

fileprivate func drawRect(handle: VoidPtr, x: Int32, y :Int32, w: Int32, h: Int32, colour: Int32) -> Void {
    let gv = getGV(handle: handle)
    let comps = rgb(gv: gv, colour: colour)
    gv.bitmap!.setFillColor(red: comps[0], green: comps[1], blue: comps[2], alpha: 1)
    gv.bitmap!.fill(CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(w), height: CGFloat(h)))
}

fileprivate func drawLine(handle: VoidPtr, x: Int32, y: Int32, x2: Int32, y2: Int32, colour: Int32) -> Void {
    let gv = getGV(handle: handle)
    let comps = rgb(gv: gv, colour: colour)
    gv.bitmap!.setStrokeColor(red: comps[0], green: comps[1], blue: comps[2], alpha: 1)
    gv.bitmap!.beginPath()
    gv.bitmap!.move(to: CGPoint(x: CGFloat(x), y: CGFloat(y)))
    gv.bitmap!.addLine(to: CGPoint(x: CGFloat(x2), y: CGFloat(y2)))
    gv.bitmap!.strokePath()
}

fileprivate func drawPolygon(handle: VoidPtr, coords: Int32Ptr, npoints: Int32, fillcolour: Int32, outlinecolour: Int32) -> Void {
    let gv = getGV(handle: handle)
    var comps = rgb(gv: gv, colour: outlinecolour)
    gv.bitmap!.setStrokeColor(red: comps[0], green: comps[1], blue: comps[2], alpha: 1)
    gv.bitmap!.beginPath()
    gv.bitmap!.move(to: CGPoint(x: CGFloat(coords![0]), y: CGFloat(coords![1])))
    for i in 0..<Int(npoints) {
        gv.bitmap!.addLine(to: CGPoint(x: CGFloat(coords![2 * i]), y: CGFloat(coords![2 * i + 1])))
    }
    gv.bitmap!.closePath()
    if (fillcolour >=  0) {
        comps = rgb(gv: gv, colour: fillcolour)
        gv.bitmap!.setFillColor(red: comps[0], green: comps[1], blue: comps[2], alpha: 1)
    }
    let mode = fillcolour >= 0 ? CGPathDrawingMode.fillStroke : CGPathDrawingMode.stroke
    gv.bitmap!.drawPath(using: mode)
}

fileprivate func drawCircle(handle: VoidPtr, cx: Int32, cy: Int32, radius: Int32, fillcolour: Int32, outlinecolour: Int32) -> Void {
    let gv = getGV(handle: handle)
    var comps = rgb(gv: gv, colour: outlinecolour)
    let r = CGRect(x: CGFloat(cx-radius+1), y: CGFloat(cy-radius+1), width: CGFloat(radius*2-1), height: CGFloat(radius*2-1))
    gv.bitmap!.setStrokeColor(red: comps[0], green: comps[1], blue: comps[2], alpha: 1)
    gv.bitmap!.beginPath()
    gv.bitmap!.strokePath()
    if (fillcolour >=  0) {
        comps = rgb(gv: gv, colour: fillcolour)
        gv.bitmap!.setFillColor(red: comps[0], green: comps[1], blue: comps[2], alpha: 1)
        gv.bitmap!.fillEllipse(in: r)
    }
    gv.bitmap!.strokeEllipse(in: r)
}

fileprivate func drawUpdate(handle: VoidPtr, x: Int32, y: Int32, w: Int32, h: Int32) {
    getGV(handle: handle).drawGameRect(rect: CGRect(x: Int(x), y: Int(y), width: Int(w), height: Int(h)))
}

fileprivate func clip(handle: VoidPtr, x: Int32, y: Int32, w: Int32, h: Int32) -> Void {
    let gv = getGV(handle: handle)
    if (!gv.fe.clipping) {
        gv.bitmap!.saveGState()
    }
    gv.bitmap!.clip(to: CGRect(x: Int(x), y: Int(y), width: Int(w), height: Int(h)))
    gv.fe.clipping = true
}

fileprivate func unclip(handle: VoidPtr) -> Void {
    let gv = getGV(handle: handle)
    if (gv.fe.clipping) {
        gv.bitmap!.restoreGState()
    }
    gv.fe.clipping = false
}

fileprivate func startDraw(handle: VoidPtr) -> Void {
    
}

fileprivate func endDraw(handle: VoidPtr) -> Void {
    
}

fileprivate func statusBar(handle: VoidPtr, text: ConstCharPtr) -> Void {
    getGV(handle: handle).statusbar?.text = String(cString: text!)
}

class Blitter {
    var x: Int32 = 0
    var y: Int32 = 0
    var w: Int32 = 0
    var h: Int32 = 0
    var ox: Int32 = 0
    var oy: Int32 = 0
    var img: CGImage?
    
    init(x: Int32, y: Int32, w: Int32, h: Int32) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }
}

fileprivate func blitterNew(handle: VoidPtr, w: Int32, h: Int32) -> OpaquePointer? {
    let b = Blitter.init(x: -1, y: -1, w: w, h: w)
    getGV(handle: handle).blitter = b
    return OpaquePointer(bridge(obj: b))
}

fileprivate func blitterFree(handle: VoidPtr, blitter: OpaquePointer?) -> Void {
    getGV(handle: handle).blitter = nil
}

fileprivate func blitterSave(handle: VoidPtr, blitter: OpaquePointer?, x: Int32, y: Int32) -> Void {
    let gv = getGV(handle: handle)
    let b = gv.blitter!
    let r = CGRect(x: Int(x), y: Int(y), width: Int(b.w), height: Int(b.h))
    let r2 = CGRect(x: 0, y: 0, width: gv.bitmap!.width, height: gv.bitmap!.height)
    let v = r.intersection(r2)
    b.x = x
    b.y = y
    b.ox = Int32(v.origin.x)
    b.oy = Int32(v.origin.y)
    b.img = gv.bitmap!.makeImage()?.cropping(to: v)
}

fileprivate func blitterLoad(handle: VoidPtr, blitter: OpaquePointer?, x: Int32, y: Int32) -> Void {
    let gv = getGV(handle: handle)
    let bl = gv.blitter!
    var x = x
    var y = y
    
    if (x == BLITTER_FROMSAVED && y == BLITTER_FROMSAVED) {
        x = bl.x;
        y = bl.y;
    }
    x += bl.ox;
    y += bl.oy;

    let r = CGRect(x: Int(x), y: Int(y), width: Int(bl.w), height: Int(bl.h))
    gv.bitmap!.draw(bl.img!, in: r)
}

fileprivate func textFallback(handle: VoidPtr, strings: ConstCharPtrConstPtr, nStrings: Int32) -> CharPtr {
    return dupstr(strings![0]!)
}

fileprivate func attach_timer(fe: UnsafePointer<frontend>) -> Void {
    let ptr = fe.pointee.gv
    let gv: GameView = bridge(ptr: ptr!)
    gv.activateTimer()
}

fileprivate func detach_timer(fe: UnsafePointer<frontend>) -> Void {
    let ptr = fe.pointee.gv
    let gv: GameView = bridge(ptr: ptr!)
    gv.deactivateTimer()
}
