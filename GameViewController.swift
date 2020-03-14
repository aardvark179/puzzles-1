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

class GameViewController : UIViewController {
    var theGame: UnsafeMutablePointer<game>
    var name: String = ""
    var saved: String?
    var initInProgress: Bool = false
    var gameView: GameView? = nil
    var saver: GameViewControllerSaver
    
    init(game: UnsafeMutablePointer<game>, saved: String?, inProgress:Bool, saver: GameViewControllerSaver) {
        self.theGame = game
        self.name = String.init(cString: game.pointee.name)
        self.saved = saved
        self.initInProgress = inProgress
        self.saver = saver
        super.init(nibName: nil, bundle: nil)
        self.title = name
        NotificationCenter.default.addObserver(self, selector: #selector(saveGame), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func loadView() {
        self.gameView = GameView(nc: navigationController!, game: theGame, saved: saved, inProgess: initInProgress, frame: UIScreen.main.bounds)
        self.view = self.gameView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Help", style: .plain, target: self, action: #selector(showHelp))
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

