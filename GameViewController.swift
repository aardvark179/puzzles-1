//
//  GameViewController.swift
//  Puzzles
//
//  Created by Duncan MacGregor on 04/03/2020.
//  Copyright © 2020 Greg Hewgill. All rights reserved.
//

import Foundation
import UIKit

protocol GameViewControllerSaver {
    func saveGame(name: String, state: String, inProgress: Bool)
}

class GameViewController : UIViewController, GameSettingsDelegate {
    var theGame: UnsafePointer<game>
    var midend: OpaquePointer! = nil {
        didSet {
            self.gameView?.midend = midend
        }
    }
    var fe: frontend = frontend(gv: nil, colours: nil, ncolours: 0, clipping: false, activate_timer: {fe in attach_timer(fe: fe!)}, deactivate_timer: {fe in detach_timer(fe: fe!)}, default_colour: {fe, output in frontendDefaultColour(fe: fe, output: output)})
    var name: String = ""
    var saved: String?
    var initInProgress: Bool = false
    var gameView: GameView? = nil
    var saver: GameViewControllerSaver
    
    init(game: UnsafePointer<game>, saved: String?, inProgress:Bool, saver: GameViewControllerSaver) {
        self.theGame = game
        // Set the environment to set the preferred tile size...
        let key = "\(String(cString: theGame.pointee.name).uppercased().replacingOccurrences(of: " ", with: ""))_TILESIZE"
        let value = "\(theGame.pointee.preferred_tilesize * 4)"
        setenv(key, value, 1)
        
        self.name = String.init(cString: game.pointee.name)
        self.saved = saved
        self.initInProgress = inProgress
        self.saver = saver
        super.init(nibName: nil, bundle: nil)
        self.title = name
        NotificationCenter.default.addObserver(self, selector: #selector(saveGame), name: UIApplication.didEnterBackgroundNotification, object: nil)
        let items = [
            UIBarButtonItem(title: "Game", style: .plain, target: self, action: #selector(doGameMenu)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .undo,  target: self, action: #selector(doUndo)),
            UIBarButtonItem(barButtonSystemItem: .redo, target: self, action: #selector(doRedo)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "Type", style: .plain, target: self,    action: #selector(doType)),
        ]

        toolbarItems = items
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        if (midend != nil) {
            midend_free(midend);
        }
    }

    override func loadView() {
        self.gameView = GameView(
            game: theGame,
            saved: saved,
            inProgess: initInProgress,
            frame: UIScreen.main.bounds)
        self.view = self.gameView
        midend = midend_new(&fe, theGame, &swift_drawing_api, bridge(obj: self));
        fe.gv = bridge(obj: gameView!)
        fe.colours = midend_colours(midend, &fe.ncolours);
        gameView!.backgroundColor = UIColor.init(red: CGFloat(fe.colours![0]), green: CGFloat(fe.colours![1]), blue: CGFloat(fe.colours![2]), alpha: 1)
    }

    func startNewGame() {
        let m: OpaquePointer = self.midend
        self.midend = nil
        let window: UIWindow = UIApplication.shared.windows[0]
        
        // Create a clear overlau to consume touches during puzzle generation
        let overlay: UIView = UIView.init(frame: window.rootViewController!.view.bounds)
        window.rootViewController!.view.addSubview(overlay)
        
        let (box, aiv) = gameView!.createProgressIndicator(overlay: overlay)
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(250)) {
            box.isHidden = false
        }
        
        DispatchQueue.global().async {
            midend_new_game(m)
            DispatchQueue.main.async {
                aiv.stopAnimating()
                overlay.removeFromSuperview()
                self.midend = m
                self.gameView!.layoutSubviews()
            }
        }
    }

    func didApply(config: UnsafeMutablePointer<config_item>) {
        let msg = midend_game_id(midend, config[0].name)
        if (msg != nil) {
            let alert = UIAlertController(title: "Puzzles", message: String(cString: msg!), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Close", style: .cancel, handler: nil))
            navigationController!.present(alert, animated: false, completion: nil)
        }
        startNewGame()
        navigationController!.popViewController(animated: true)
    }
    
    func didApply(item: UnsafeMutablePointer<config_item>) {
        let msg = midend_game_id(midend, item[0].name)
        if (msg != nil) {
            let alert = UIAlertController(title: "Puzzles", message: String(cString: msg!), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            navigationController!.present(alert, animated: false, completion: nil)
            return
        }
        startNewGame()
        navigationController!.popToRootViewController(animated: true)
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
        pop?.barButtonItem = navigationController?.toolbar!.items![0]
        navigationController!.present(gameMenu, animated: true, completion: nil)
    }
    
    func doSpecificGame() {
        var winTitle: CharPtr = nil
        let config = midend_get_config(midend, Int32(CFG_DESC), &winTitle)
        navigationController!.pushViewController(GameSettingsController(game: theGame, config_items: config!, type: CFG_DESC, title: String(cString: winTitle!), delegate: self), animated: true)
        free(winTitle)
    }
    
    func doSpecificSeed() {
        var winTitle: CharPtr = nil
        let config = midend_get_config(midend, Int32(CFG_SEED), &winTitle)
        navigationController!.pushViewController(GameSettingsController(game: theGame, config_items: config!, type: CFG_SEED, title: String(cString: winTitle!), delegate: self), animated: true)
        free(winTitle)
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
            navigationController!.present(alert, animated: false, completion: nil)
        }
    }
    
    @objc func doType() {
        navigationController!.pushViewController(GameTypeController(game: theGame, midend: midend, controller: self), animated: true)
    }

    override func viewDidLoad() {
        if (saved != nil) {
            let ctx = StringReadConext(save: saved!, position: 0)
            let msg = midend_deserialise(midend, {ctx, buffer, length in saveGameRead(ctx: ctx, buffer: buffer, length: length)}, bridge(obj: ctx))
            if (msg != nil) {
                let alert = UIAlertController(title: "Puzzles", message: String(cString: msg!), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                navigationController?.present(alert, animated: false, completion: nil)
                startNewGame()
            } else if (!initInProgress) {
                startNewGame()
            }
        } else {
            if (theGame == pattern_ptr && traitCollection.horizontalSizeClass == .compact || traitCollection.verticalSizeClass == .compact) {
                midend_game_id(midend, "S")
            }
            startNewGame()
        }
        super.viewDidLoad()

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Help", style: .plain, target: self, action: #selector(showHelp))
        if traitCollection.verticalSizeClass == .compact {
            navigationController?.hidesBarsOnSwipe = true
        } else {
            navigationController?.hidesBarsOnSwipe = false
        }
    }
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
//        if traitCollection.verticalSizeClass == .compact {
//            navigationController?.hidesBarsOnTap = true
//        } else {
//            navigationController?.hidesBarsOnTap = false
//        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        saveGame()
    }
    
    @objc func saveGame() {
        var inProgess: Bool = false
        let saved: String? = gameView?.saveGame(inProgress: &inProgess)
        if (saved != nil) {
            saver.saveGame(name: name, state: saved!, inProgress: inProgess)
        }
    }
    
    @objc func showHelp() {
        navigationController?.pushViewController(GameHelpController(file: String.init(format: "%s.html", theGame.pointee.htmlhelp_topic)), animated: true)
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

