//
//  GameSettingController.swift
//  Puzzles
//
//  Created by Duncan MacGregor on 11/03/2020.
//  Copyright © 2020 Greg Hewgill. All rights reserved.
//

import Foundation
import UIKit

protocol GameSettingsDelegate {
    func didApply(item: UnsafeMutablePointer<config_item>)
}

class GameSettingsController :UITableViewController, GameSettingsChoiceControllerDelegate {
    var game: UnsafePointer<game>
    var config_items: UnsafeMutablePointer<config_item>
    var type: Int
    var delegate: GameSettingsDelegate
    var num: Int
    var choiceText: [[String]]
    
    init(game: UnsafePointer<game>, config_items: UnsafeMutablePointer<config_item>, type: Int, title: String, delegate: GameSettingsDelegate) {
        self.game = game
        self.config_items = config_items
        self.type = type
        self.delegate = delegate
        num = 0
        var choices = Array<[String]>()
        while (config_items[num].type != C_END) {
            if (config_items[num].type == C_STRING) {
                let sval = String(cString: config_items[num].u.string.sval)
                let delimiter = sval.first!
                let parts = sval.split(separator: delimiter, omittingEmptySubsequences: true)
                choices.append(parts.map({ss in String(ss)}))
            }
            num += 1;
        }
        self.choiceText = choices
        super.init(style: .grouped)
        self.title = title
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        free_cfg(UnsafeMutablePointer(mutating: config_items))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "help", style: .plain, target: self, action: #selector(showHelp))
    }
    
    @objc func showHelp() {
        navigationController?.pushViewController(GameHelpController(file: String.init(format: "%s.html", game.pointee.htmlhelp_topic)), animated: true)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch (section) {
            case 0:
                return num;
            case 1:
                return 1;
            default:
                return 0;
        }
    }

    fileprivate func textItem(_ offset: CGFloat, _ indexPath: IndexPath, _ cell: UITableViewCell) {
        let w = (self.view.frame.width) - 100 - offset
        let r = CGRect.init(x: w, y: 12, width: 80, height: 31)
        let text = UITextField(frame: r)
        text.tag = indexPath.row
        text.addTarget(self, action: #selector(valueChanged), for: .editingChanged)
        text.textAlignment = .right
        text.text = String(cString: config_items[indexPath.row].u.string.sval)
        cell.addSubview(text)
    }
    
    fileprivate func switchItem(_ offset: CGFloat, _ indexPath: IndexPath, _ cell: UITableViewCell) {
        let sw = UISwitch(frame: CGRect(x: self.view.frame.width - 95 - offset, y: 9, width: 80, height: 31))
        sw.tag = indexPath.row
        sw.addTarget(self, action: #selector(valueChanged), for: .valueChanged)
        sw.isOn = config_items[indexPath.row].u.boolean.bval
        cell.addSubview(sw)
    }
    
    fileprivate func choicesItem(_ cell: UITableViewCell, _ offset: CGFloat, _ indexPath: IndexPath) {
        cell.accessoryType = .disclosureIndicator
        let label = UITextField(frame: CGRect(x: self.view.frame.width-200-offset, y: 11, width: 165, height: 31))
        label.isEnabled = false
        label.textAlignment = .right
        label.text = choiceText[indexPath.row][Int(config_items[indexPath.row].u.choices.selected)]
        cell.addSubview(label)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        let offset: CGFloat =  (traitCollection.horizontalSizeClass == .compact) ? 0 : 40
        cell.selectionStyle = .none
        switch (indexPath.section) {
        case 0:
            if (type == CFG_SETTINGS) {
                cell.textLabel?.text = String(cString: config_items[indexPath.row].name)
                switch (Int(config_items[indexPath.row].type)) {
                case C_STRING:
                    textItem(offset, indexPath, cell)
                case C_BOOLEAN:
                    switchItem(offset, indexPath, cell)
                case C_CHOICES:
                    choicesItem(cell, offset, indexPath)
                default:
                    break
                }
            } else {
                let text = UITextField(frame: CGRect(x: 20+offset, y: 12, width: view.frame.width-(20+offset), height: 31))
                text.tag = indexPath.row
                text.addTarget(self, action: #selector(valueChanged), for: .editingChanged)
                text.text = String(cString: config_items[indexPath.row].u.string.sval)
                cell.addSubview(text)
            }
        case 1:
            cell.textLabel?.text = "Apply"
            cell.textLabel?.textAlignment = .center
        default:
            break
        }
        return cell;
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if (previousTraitCollection?.horizontalSizeClass != traitCollection.horizontalSizeClass || previousTraitCollection?.verticalSizeClass != traitCollection.verticalSizeClass) {
            tableView.reloadData()
        }
    }
    
    @objc func valueChanged(sender: UIControl) {
        switch(Int(config_items[sender.tag].type)) {
        case C_STRING:
            free(config_items[sender.tag].u.string.sval)
            config_items[sender.tag].u.string.sval = dupstr((sender as! UITextField).text?.cString(using: .utf8))
        case C_BOOLEAN:
            config_items[sender.tag].u.boolean.bval = (sender as! UISwitch).isOn
        default:
            break
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (indexPath.section == 0) {
            if (config_items[indexPath.row].type == C_CHOICES) {
                let choices = choiceText[indexPath.row]
                let value = config_items[indexPath.row].u.choices.selected
                let title = String(cString: config_items[indexPath.row].name)
                let gscc = GameSettingsChoiceController(game: game, index: indexPath.row, choices: choices, value: Int(value), title: title, delegate: self)
                navigationController?.pushViewController(gscc, animated: true)
            }
        }
        if (indexPath.section == 1 && indexPath.row == 0) {
            delegate.didApply(item: config_items)
        }
    }
    
    func didSelectChoice(index: Int, value: Int) {
        config_items[index].u.choices.selected = Int32(value)
        tableView.reloadData()
    }
}
