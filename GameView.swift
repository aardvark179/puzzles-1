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

class GameView : UIView, UIGestureRecognizerDelegate {
    var theGame: UnsafePointer<game>
    var midend: OpaquePointer!
    var usableFrame: CGRect!
    var gameRect: CGRect!
    var timer: Timer!
    var gameToolbar: UIToolbar? = nil
    var touchState: Int = 0
    var touchXPoints: Int32 = 0
    var touchYPoints: Int32 = 0
    var touchXPixels: Int32 = 0
    var touchYPixels: Int32 = 0
    var touchButton: Int = 0
    var toolbar: UIToolbar?
    var buttons: Dictionary<String, UIBarButtonItem> = Dictionary<String, UIBarButtonItem>()
    var statusbar: UILabel?
    var bitmap: CGContext?
    var blitters: Set<Blitter> = Set()
    var tapRecogniser: UITapGestureRecognizer!
    var longPressRecogniser: UILongPressGestureRecognizer!
 
    init(game: UnsafePointer<game>, saved:String?, inProgess:Bool, frame:CGRect) {
        self.midend = nil
        theGame = game
        super.init(frame: frame)
        tapRecogniser = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapRecogniser.delaysTouchesBegan = true
        tapRecogniser.delegate = self
        longPressRecogniser = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressRecogniser.delaysTouchesBegan = true
        addGestureRecognizer(tapRecogniser)
        addGestureRecognizer(longPressRecogniser)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func netCentreMode() -> Bool {
        return (theGame == net_ptr) && buttons["Centre"]?.style == .done
    }
    
    fileprivate func netShiftMode() -> Bool {
        return (theGame == net_ptr) && buttons["Shift"]?.style == .done
    }
    
    fileprivate func buildStatusBar() {
        if (midend_wants_statusbar(midend)) {
            if (statusbar == nil) {
                statusbar = UILabel()
                self.addSubview(self.statusbar!)
                let constraints: [NSLayoutConstraint]
                if #available(iOS 11.0, *) {
                    constraints = [
                        statusbar!.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
                        statusbar!.heightAnchor.constraint(greaterThanOrEqualToConstant: 20.0),
                        statusbar!.widthAnchor.constraint(equalTo: self.widthAnchor)
                    ]
                } else {
                    constraints = [
                        statusbar!.bottomAnchor.constraint(equalTo: bottomAnchor),
                        statusbar!.heightAnchor.constraint(greaterThanOrEqualToConstant: 20.0),
                        statusbar!.widthAnchor.constraint(equalTo: self.widthAnchor)
                    ]
                }
                statusbar!.translatesAutoresizingMaskIntoConstraints = false
                statusbar!.numberOfLines = 1
                    NSLayoutConstraint.activate(constraints)
            }
        } else {
            statusbar?.removeFromSuperview()
            statusbar = nil
        }
    }
    
    func populateGameBar() {
        buttons.removeAll()
        if (theGame == filling_ptr
             || theGame == keen_ptr
             || theGame == map_ptr
             || theGame == net_ptr
             || theGame == solo_ptr
             || theGame == towers_ptr
             || theGame == undead_ptr
             || theGame == unequal_ptr) {
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
                let gotX = scanner.scanInt(&x)
                _ = scanner.scanUpTo("x", into: nil)
                let gotY = scanner.scanInt(&y)
                
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
                main_button_count = Int(String(String(cString: midend_get_game_id(midend)).split(separator: ":").first!))!;
                extra_labels = unequalLabels;
                extra_button_count = 2;
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
            gameToolbar!.setItems(items, animated: false)
        }
    }
    
    fileprivate func buildGameButtons() {
        if (theGame == filling_ptr
             || theGame == keen_ptr
             || theGame == map_ptr
             || theGame == net_ptr
             || theGame == solo_ptr
             || theGame == towers_ptr
             || theGame == undead_ptr
             || theGame == unequal_ptr) {
            if (gameToolbar == nil) {
                gameToolbar = UIToolbar()
                addSubview(gameToolbar!)
                let constraints: [NSLayoutConstraint]
                if (statusbar != nil) {
                    constraints = [
                        gameToolbar!.bottomAnchor.constraint(equalTo: statusbar!.topAnchor),
                        gameToolbar!.widthAnchor.constraint(equalTo: widthAnchor)
                    ]
                } else {
                    if #available(iOS 11.0, *) {
                        constraints = [
                            gameToolbar!.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
                            gameToolbar!.widthAnchor.constraint(equalTo: widthAnchor)
                        ]
                    } else {
                        constraints = [
                            gameToolbar!.bottomAnchor.constraint(equalTo: bottomAnchor),
                            gameToolbar!.widthAnchor.constraint(equalTo: widthAnchor)
                        ]
                    }
                }
                gameToolbar!.translatesAutoresizingMaskIntoConstraints = false
                gameToolbar!.sizeToFit()
                NSLayoutConstraint.activate(constraints)
                populateGameBar()
            }
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
    
    fileprivate func transformTouchPoint(_ point: CGPoint, _ inRect: Bool) -> (Int32, Int32, Int32, Int32) {
        let p = CGPoint(x: point.x - gameRect.origin.x, y: point.y - gameRect.origin.y)
        let pointX: Int32
        let pointY: Int32
        if (inRect) {
            pointX = Int32(min(gameRect.width - 1, max(p.x, 0)))
            pointY = Int32(min(gameRect.height - 1, max(p.y, 0)))
        } else {
            pointX = Int32(p.x)
            pointY = Int32(p.y)
        }
        let pixelX: Int32 = Int32(p.x * contentScaleFactor)
        let pixelY: Int32 = Int32(p.y * contentScaleFactor)
        return (pointX, pointY, pixelX, pixelY)
    }
    
    fileprivate func transformTouch(touches: Set<UITouch>, inRect: Bool) -> (Int32, Int32, Int32, Int32) {
        let touch = touches.first
        let p = touch!.location(in: self)
        return transformTouchPoint(p, inRect)
    }
    
    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        if (sender.state == .ended) {
            (touchXPoints, touchYPoints, touchXPixels, touchYPixels) = transformTouchPoint(sender.location(in: self), false)
            if (netCentreMode()) {
                midend_process_key(midend, touchXPixels, touchYPixels, 0x03)
            } else {
                midend_process_key(midend, touchXPixels, touchYPixels, ButtonDown[0])
                midend_process_key(midend, touchXPixels, touchYPixels, ButtonUp[0])
            }
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if (gestureRecognizer == tapRecogniser && otherGestureRecognizer == longPressRecogniser) {
            return true
        } else {
            return false
        }
    }
    
    @objc func handleLongPress(_ sender: UILongPressGestureRecognizer) {
        (touchXPoints, touchYPoints, touchXPixels, touchYPixels) = transformTouchPoint(sender.location(in: self), false)
        switch (sender.state) {
        case (.began):
            if (netShiftMode()) {
                return
            } else if (netCentreMode()) {
                return
            } else {
                let button = theGame == net_ptr ? 2 : 1
                midend_process_key(midend, touchXPixels, touchYPixels, ButtonDown[button])
            }
        case (.ended):
            if (netShiftMode()) {
                return
            } else if (netCentreMode()) {
                midend_process_key(midend, touchXPixels, touchYPixels, 0x03)
            } else {
                let button = theGame == net_ptr ? 2 : 1
                midend_process_key(midend, touchXPixels, touchYPixels, ButtonUp[button])
            }
        case (.changed):
            if (netShiftMode()) {
                return
            } else if (netCentreMode()) {
                return
            } else {
                let button = theGame == net_ptr ? 2 : 1
                midend_process_key(midend, touchXPixels, touchYPixels, ButtonDrag[button])
            }
        default:
            return;
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        (touchXPoints, touchYPoints, touchXPixels, touchYPixels) = transformTouch(touches: touches, inRect: false)
        touchState = 1
        touchButton = 0
        if (netCentreMode()) {
            midend_process_key(midend, touchXPixels, touchYPixels, 0x03)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let (xPoints, yPoints, xPixels, yPixels) = transformTouch(touches: touches, inRect: true)
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
            while (touchYPixels <= yPixels - ts) {
                midend_process_key(midend, -1, -1, Int32(MOD_SHFT | CURSOR_UP))
                touchYPixels -= ts
            }
            while (touchYPixels >= yPixels - ts) {
                midend_process_key(midend, -1, -1, Int32(MOD_SHFT | CURSOR_DOWN))
                touchYPixels += ts
            }
        } else {
            if (touchState == 1) {
                if (abs(xPoints + touchXPoints) >= 10 || abs(yPoints + touchYPoints) >= 10) {
                    midend_process_key(midend, touchXPixels, touchYPixels, ButtonDown[touchButton]);
                    touchState = 2;
                }
            }
            if (touchState == 2) {
                midend_process_key(midend, xPixels, yPixels, ButtonDrag[touchButton])
            }
        }

    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let (_, _   , xPixels, yPixels) = transformTouch(touches: touches, inRect: true)
        if (netCentreMode() || netShiftMode()) {
            return
        } else {
            if (touchState == 1) {
                midend_process_key(midend, touchXPixels, touchYPixels, ButtonDown[touchButton])
            }
            midend_process_key(midend, xPixels, yPixels, ButtonUp[touchButton])
        }
        touchState = 0
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchState = 0
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
        
    override func layoutSubviews() {
        super.layoutSubviews()
        if (self.midend == nil) {
            return
        }
        
        buildStatusBar()
        buildGameButtons()
        
        let topMargin: CGFloat
        if #available(iOS 11.0, *) {
            topMargin = frame.minY + safeAreaInsets.top
        } else {
            topMargin = frame.minY
        }
        
        var bottomMargin: CGFloat = 0
        if (gameToolbar != nil) {
            bottomMargin += gameToolbar!.bounds.height
        }
        if (statusbar != nil) {
            bottomMargin += statusbar!.bounds.height
        }
        
        if #available(iOS 11.0, *) {
            bottomMargin += safeAreaInsets.bottom
        } else {
            bottomMargin += 50
        }
        
        usableFrame = CGRect(x: 0, y: topMargin, width: self.frame.width, height: frame.height - topMargin - bottomMargin)
        let fw = Int32(frame.width * contentScaleFactor)
        let fh = Int32(usableFrame.height * contentScaleFactor)
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

fileprivate func getGVC(handle: VoidPtr) -> GameViewController {
    return bridge(ptr: UnsafeMutableRawPointer(OpaquePointer(handle))!)
}

func getGV(handle: VoidPtr) -> GameView {
    return getGVC(handle: handle).gameView!
}

fileprivate func getBitmap(handle: VoidPtr) -> CGContext {
    return getGVC(handle: handle).gameView!.bitmap!
}

fileprivate func rgba(gvc: GameViewController, colour: Int32) -> [CGFloat] {
    return [CGFloat(gvc.fe.colours![Int(colour) * 3 + 0]),
            CGFloat(gvc.fe.colours![Int(colour) * 3 + 1]),
            CGFloat(gvc.fe.colours![Int(colour) * 3 + 2]),
            1
    ]
}
fileprivate func drawText(handle: VoidPtr, x: Int32, y: Int32, fontType: Int32, fontSize: Int32, align: Int32, colour: Int32, text: ConstCharPtr?) -> Void {
    let gvc = getGVC(handle: handle)
    let str = String(cString: text!!)
    let font = CTFontCreateWithName("Helvetica" as CFString, CGFloat(fontSize), nil)
    let cs = CGColorSpaceCreateDeviceRGB()
    let comps: [CGFloat] = rgba(gvc: gvc, colour: colour)
    let colour = CGColor(colorSpace: cs, components: comps)
    let attributes: Dictionary<CFString, Any?> = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: colour]
    let attrStr = CFAttributedStringCreate(nil, str as CFString, attributes as CFDictionary)
    let line = CTLineCreateWithAttributedString(attrStr!)
    getBitmap(handle: handle).textMatrix = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0)
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
    getBitmap(handle: handle).textPosition = CGPoint(x: tx, y: ty)
    CTLineDraw(line, getBitmap(handle: handle));
}

fileprivate func drawRect(handle: VoidPtr, x: Int32, y :Int32, w: Int32, h: Int32, colour: Int32) -> Void {
    let gvc = getGVC(handle: handle)
    let comps = rgba(gvc: gvc, colour: colour)
    getBitmap(handle: handle).setFillColor(red: comps[0], green: comps[1], blue: comps[2], alpha: 1)
    getBitmap(handle: handle).fill(CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(w), height: CGFloat(h)))
}

fileprivate func drawLine(handle: VoidPtr, x: Int32, y: Int32, x2: Int32, y2: Int32, colour: Int32) -> Void {
    let gvc = getGVC(handle: handle)
    let comps = rgba(gvc: gvc, colour: colour)
    getBitmap(handle: handle).setStrokeColor(red: comps[0], green: comps[1], blue: comps[2], alpha: 1)
    getBitmap(handle: handle).beginPath()
    getBitmap(handle: handle).move(to: CGPoint(x: CGFloat(x), y: CGFloat(y)))
    getBitmap(handle: handle).addLine(to: CGPoint(x: CGFloat(x2), y: CGFloat(y2)))
    getBitmap(handle: handle).strokePath()
}

fileprivate func drawPolygon(handle: VoidPtr, coords: Int32Ptr, npoints: Int32, fillcolour: Int32, outlinecolour: Int32) -> Void {
    let gvc = getGVC(handle: handle)
    var comps = rgba(gvc: gvc, colour: outlinecolour)
    getBitmap(handle: handle).setStrokeColor(red: comps[0], green: comps[1], blue: comps[2], alpha: 1)
    getBitmap(handle: handle).beginPath()
    getBitmap(handle: handle).move(to: CGPoint(x: CGFloat(coords![0]), y: CGFloat(coords![1])))
    for i in 0..<Int(npoints) {
        getBitmap(handle: handle).addLine(to: CGPoint(x: CGFloat(coords![2 * i]), y: CGFloat(coords![2 * i + 1])))
    }
    getBitmap(handle: handle).closePath()
    if (fillcolour >=  0) {
        comps = rgba(gvc: gvc, colour: fillcolour)
        getBitmap(handle: handle).setFillColor(red: comps[0], green: comps[1], blue: comps[2], alpha: 1)
    }
    let mode = fillcolour >= 0 ? CGPathDrawingMode.fillStroke : CGPathDrawingMode.stroke
    getBitmap(handle: handle).drawPath(using: mode)
}

fileprivate func drawCircle(handle: VoidPtr, cx: Int32, cy: Int32, radius: Int32, fillcolour: Int32, outlinecolour: Int32) -> Void {
    let gvc = getGVC(handle: handle)
    var comps = rgba(gvc: gvc, colour: outlinecolour)
    let r = CGRect(x: CGFloat(cx-radius+1), y: CGFloat(cy-radius+1), width: CGFloat(radius*2-1), height: CGFloat(radius*2-1))
    getBitmap(handle: handle).setStrokeColor(red: comps[0], green: comps[1], blue: comps[2], alpha: 1)
    getBitmap(handle: handle).beginPath()
    getBitmap(handle: handle).strokePath()
    if (fillcolour >=  0) {
        comps = rgba(gvc: gvc, colour: fillcolour)
        getBitmap(handle: handle).setFillColor(red: comps[0], green: comps[1], blue: comps[2], alpha: 1)
        getBitmap(handle: handle).fillEllipse(in: r)
    }
    getBitmap(handle: handle).strokeEllipse(in: r)
}

fileprivate func drawUpdate(handle: VoidPtr, x: Int32, y: Int32, w: Int32, h: Int32) {
    getGV(handle: handle).drawGameRect(rect: CGRect(x: Int(x), y: Int(y), width: Int(w), height: Int(h)))
}

fileprivate func clip(handle: VoidPtr, x: Int32, y: Int32, w: Int32, h: Int32) -> Void {
    let gvc = getGVC(handle: handle)
    if (!gvc.fe.clipping) {
        getBitmap(handle: handle).saveGState()
    }
    getBitmap(handle: handle).clip(to: CGRect(x: Int(x), y: Int(y), width: Int(w), height: Int(h)))
    gvc.fe.clipping = true
}

fileprivate func unclip(handle: VoidPtr) -> Void {
    let gvc = getGVC(handle: handle)
    if (gvc.fe.clipping) {
        getBitmap(handle: handle).restoreGState()
    }
    gvc.fe.clipping = false
}

fileprivate func startDraw(handle: VoidPtr) -> Void {
    
}

fileprivate func endDraw(handle: VoidPtr) -> Void {
    
}

fileprivate func statusBar(handle: VoidPtr, text: ConstCharPtr) -> Void {
    getGV(handle: handle).statusbar?.text = String(cString: text!)
}

class Blitter : Hashable {
    static func == (lhs: Blitter, rhs: Blitter) -> Bool {
        return lhs === rhs
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(bridge(obj: self).hashValue)
    }
    
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
fileprivate  func getBlitter(ptr: OpaquePointer) -> Blitter {
    return bridge(ptr: UnsafeMutablePointer(ptr))
}

fileprivate func blitterNew(handle: VoidPtr, w: Int32, h: Int32) -> OpaquePointer? {
    let b = Blitter.init(x: -1, y: -1, w: w, h: w)
    getGV(handle: handle).blitters.insert(b)
    return OpaquePointer(bridge(obj: b))
}

fileprivate func blitterFree(handle: VoidPtr, blitter: OpaquePointer?) -> Void {
    getGV(handle: handle).blitters.remove(getBlitter(ptr: blitter!))
}

fileprivate func blitterSave(handle: VoidPtr, blitter: OpaquePointer?, x: Int32, y: Int32) -> Void {
    let b = getBlitter(ptr: blitter!)
    let r = CGRect(x: Int(x), y: Int(y), width: Int(b.w), height: Int(b.h))
    let r2 = CGRect(x: 0, y: 0, width: getBitmap(handle: handle).width, height: getBitmap(handle: handle).height)
    let v = r.intersection(r2)
    b.x = x
    b.y = y
    b.ox = Int32(v.origin.x) - x
    b.oy = Int32(v.origin.y) - y
    b.img = getBitmap(handle: handle).makeImage()!.cropping(to: CGRect(x: v.origin.x, y: CGFloat(getBitmap(handle: handle).height) - v.origin.y - v.height, width: v.width, height: v.height))
}

fileprivate func blitterLoad(handle: VoidPtr, blitter: OpaquePointer?, x: Int32, y: Int32) -> Void {
    let bl = getBlitter(ptr: blitter!)
    var x = x
    var y = y
    
    if (x == BLITTER_FROMSAVED && y == BLITTER_FROMSAVED) {
        x = bl.x;
        y = bl.y;
    }
    x += bl.ox;
    y += bl.oy;

    let r = CGRect(x: Int(x), y: Int(y), width: Int(bl.w), height: Int(bl.h))
    getBitmap(handle: handle).draw(bl.img!, in: r)
}

fileprivate func textFallback(handle: VoidPtr, strings: ConstCharPtrConstPtr, nStrings: Int32) -> CharPtr {
    return dupstr(strings![0]!)
}
