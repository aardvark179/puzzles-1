import Foundation
import UIKit

class GameTypeController : UITableViewController, GameSettingsDelegate {
    let theGame: UnsafePointer<game>
    var midend: OpaquePointer
    var gameView: GameView
    
    init(game: UnsafePointer<game>, midend: OpaquePointer, gameView: GameView) {
        self.theGame = game
        self.midend = midend
        self.gameView = gameView
        super.init(style: .grouped)
        self.title = title
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Game Type"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Help", style: .plain, target: self, action: #selector(showHelp))
    }
    
    @objc func showHelp() {
        navigationController?.pushViewController(GameHelpController(file: String.init(format: "%s.html", theGame.pointee.htmlhelp_topic)), animated: true)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let i = number_of_presets(midend: midend) + 1
        return i
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Call")
        let pm = midend_get_presets(midend, nil)
        
        if (indexPath.row < Int(pm!.pointee.n_entries)) {
            let name = pm!.pointee.entries[indexPath.row].title
            cell.textLabel?.text = String(cString: name!)
            if (indexPath.row == Int(midend_which_preset(midend))) {
                cell.accessoryType = .checkmark
            }
        } else {
            cell.textLabel?.text = "Custom"
            if (midend_which_preset(midend) < 0) {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .disclosureIndicator
            }
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let pm = midend_get_presets(midend, nil)
        if (indexPath.row < Int(pm!.pointee.n_entries)) {
            let params = pm!.pointee.entries[indexPath.row].params
            midend_set_params(midend, params)
            gameView.startNewGame()
            navigationController?.popToViewController(gameView.next as! UIViewController, animated: true)
        } else {
            var title: UnsafeMutablePointer<Int8>? = nil
            let config = midend_get_config(midend, Int32(CFG_SETTINGS), &title)
            navigationController?.pushViewController(GameSettingsController(game: theGame, config_items: config!, type: CFG_SETTINGS, title: String(cString: title!), delegate: self), animated: true)
        }
    }
    
    func didApply(item: UnsafeMutablePointer<config_item>) {
        let msg = midend_set_config(midend, Int32(CFG_SETTINGS), item)
        if (msg != nil) {
            let alert = UIAlertController(title: "Puzzles", message: String(cString: msg!), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            present(alert, animated: false, completion: nil)
        } else {
            gameView.startNewGame()
            navigationController?.popToViewController(gameView.next as! UIViewController, animated: true)
        }
    }
}

fileprivate func number_of_presets(midend: OpaquePointer) -> Int {
    var n: Int32 = 0;
    let pm = midend_get_presets(midend, &n)
    return Int(pm!.pointee.n_entries)
}
