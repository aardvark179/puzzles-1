//
//  GameSettingChoiceController.swift
//  Puzzles
//
//  Created by Duncan MacGregor on 12/03/2020.
//  Copyright © 2020 Greg Hewgill. All rights reserved.
//

import Foundation
import UIKit

protocol GameSettingsChoiceControllerDelegate {
    func didSelectChoice(index: Int, value: Int)
}

class GameSettingsChoiceController : UITableViewController {
    let game: UnsafePointer<game>
    var index: Int
    var choices: [String]
    var delegate: GameSettingsChoiceControllerDelegate
    var value: Int
    
    init (game: UnsafePointer<game>, index: Int, choices: [String], value: Int, title: String, delegate: GameSettingsChoiceControllerDelegate) {
        self.game = game
        self.index = index
        self.choices = choices
        self.delegate = delegate
        self.value = value
        super.init(style: .grouped)
        self.title = title
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Help", style: .plain, target: self, action: #selector(showHelp))
    }
    
    @objc func showHelp() {
        navigationController?.pushViewController(GameHelpController(file: String.init(format: "%s.html", game.pointee.htmlhelp_topic)), animated: true)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return choices.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        cell.textLabel?.text = choices[indexPath.row]
        if (indexPath.row == value) {
            cell.accessoryType = .checkmark
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        delegate.didSelectChoice(index: index, value: indexPath.row)
        navigationController?.popViewController(animated: true)
    }
}
