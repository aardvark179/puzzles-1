//
//  GameListViewController.swift
//  Puzzles
//
//  Created by Duncan MacGregor on 04/03/2020.
//  Copyright © 2020 Greg Hewgill. All rights reserved.
//

import Foundation
import UIKit

let gameDescriptions: Dictionary<String, String> = [
    "Black Box": "Find the hidden balls in the box by bouncing laser beams off them.",
    "Bridges": "Connect all the islands with a network of bridges.",
    "Cube": "Pick up all the blue squares by rolling the cube over them.",
    "Dominosa": "Tile the rectangle with a full set of dominoes.",
    "Fifteen": "Slide the tiles around to arrange them into order.",
    "Filling": "Mark every square with the area of its containing region.",
    "Flip": "Flip groups of squares to light them all up at once.",
    "Flood": "Turn the grid the same colour in as few flood fills as possible.",
    "Galaxies": "Divide the grid into rotationally symmetric regions each centred on a dot.",
    "Guess": "Guess the hidden combination of colours.",
    "Inertia": "Collect all the gems without running into any of the mines.",
    "Keen": "Complete the latin square in accordance with the arithmetic clues.",
    "Light Up": "Place bulbs to light up all the squares.",
    "Loopy": "Draw a single closed loop, given clues about number of adjacent edges.",
    "Magnets": "Place magnets to satisfy the clues and avoid like poles touching.",
    "Map": "Colour the map so that adjacent regions are never the same colour.",
    "Mines": "Find all the mines without treading on any of them.",
    "Net": "Rotate each tile to reassemble the network.",
    "Netslide": "Slide a row at a time to reassemble the network.",
    "Pattern": "Fill in the pattern in the grid, given only the lengths of runs of black squares.",
    "Pearl": "Draw a single closed loop, given clues about corner and straight squares.",
    "Pegs": "Jump pegs over each other to remove all but one.",
    "Range": "Place black squares to limit the visible distance from each numbered cell.",
    "Rectangles": "Divide the grid into rectangles with areas equal to the numbers.",
    "Same Game": "Clear the grid by removing touching groups of the same colour squares.",
    "Signpost": "Connect the squares into a path following the arrows.",
    "Singles": "Black out the right set of duplicate numbers.",
    "Sixteen": "Slide a row at a time to arrange the tiles into order.",
    "Slant": "Draw a maze of slanting lines that matches the clues.",
    "Solo": "Fill in the grid so that each row, column and square block contains one of every digit.",
    "Tents": "Place a tent next to each tree.",
    "Towers": "Complete the latin square of towers in accordance with the clues.",
    "Tracks": "Fill in the railway track according to the clues.",
    "Twiddle": "Rotate the tiles around themselves to arrange them into order.",
    "Undead": "Place ghosts, vampires and zombies so that the right numbers of them can be seen in mirrors.",
    "Unequal": "Complete the latin square in accordance with the > signs.",
    "Unruly": "Fill in the black and white grid to avoid runs of three.",
    "Untangle": "Reposition the points so that the lines do not cross.",
]

enum CollectionDisplay {
    case inline
    case list
    case grid(column: Int)
}

extension CollectionDisplay : Equatable {
    
    public static func == (lhs: CollectionDisplay, rhs: CollectionDisplay) -> Bool {
        switch(lhs, rhs) {
        case(.inline, .inline),
            (.list, .list):
            return true
            
        case(.grid(let lc), .grid(let rc)):
            return lc == rc
            
        default:
            return false
        }
    }
}

class GameListViewCell : UICollectionViewCell {
    let label: UILabel
    let image: UIImageView
    let details: UILabel
    let inProgress: UIImageView
    
    override init(frame: CGRect) {
        label = UILabel()
        label.tag = 1
        label.font = .boldSystemFont(ofSize: 16)
        
        image = UIImageView()
        image.tag = 2

        details = UILabel()
        details.numberOfLines = 0
        details.tag = 3
        
        inProgress = UIImageView()
        inProgress.tag = 4
        inProgress.image = UIImage(named: "inprogress.png")
        
        super.init(frame: frame)
        if #available(iOS 13.0, *) {
            contentView.backgroundColor = .secondarySystemGroupedBackground
        } else {
            contentView.backgroundColor = .white
        }
        
        relayoutCell()
        contentView.addSubview(label)
        contentView.addSubview(image)
        contentView.addSubview(details)
        contentView.addSubview(inProgress)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if (traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass || traitCollection.verticalSizeClass != previousTraitCollection?.verticalSizeClass) {
            relayoutCell()
        }
    }
    
    func relayoutCell() {
        if (traitCollection.horizontalSizeClass == .compact) {
            // Layout for a list view
            label.frame = CGRect(x: 100, y: 0, width: frame.width - 100, height: 26)
            label.textAlignment = .left
            image.frame = CGRect(x: 2, y: 2, width: 96, height: 96)
            details.frame = CGRect(x: 100, y: 30, width: frame.width - 100, height: frame.height - 30)
            inProgress.frame = CGRect(x: frame.width - 40, y: 5, width: 40, height: 40)
        } else {
            // Layout for a grid view
            label.frame = CGRect(x: 0, y: 0, width: frame.width, height: 31)
            label.textAlignment = .center
            image.frame = CGRect(x: (frame.width - 96) / 2, y: 31, width: 96, height: 96)
            details.frame = CGRect(x: 5, y: 31 + 96, width: frame.width - 10, height: 100)
            inProgress.frame = CGRect(x: frame.width - 50, y: 50, width: 40, height: 40)
        }
    }
}

class GameListViewCollectionLayout : UICollectionViewFlowLayout {
    var display: CollectionDisplay = .list{
        didSet {
            if (display != oldValue) {
                self.invalidateLayout()
            }
        }
    }
    
    var containerWidth: CGFloat = 0.0 {
        didSet {
            if (containerWidth != oldValue) {
                self.invalidateLayout()
            }
        }
    }
    
    init(display: CollectionDisplay, collectionWidth: CGFloat) {
        self.display = display
        self.containerWidth = collectionWidth
        super.init()
        self.minimumLineSpacing = 10
        self.minimumInteritemSpacing = 10
        self.configLayout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configLayout() {
        switch(display) {
        case(.list):
            self.scrollDirection = .vertical
            self.itemSize = CGSize(width: containerWidth, height: 110)
        case(.inline):
            self.scrollDirection = .horizontal
            self.itemSize = CGSize(width: containerWidth * 0.9, height: 300)
        case(.grid(let column)):
            self.scrollDirection = .vertical
            let space = CGFloat(column) * minimumInteritemSpacing
            let optimalWidth = (containerWidth - space) / CGFloat(column)
            self.itemSize = CGSize(width: optimalWidth, height: 225)
        }
    }
    
    override func invalidateLayout() {
        super.invalidateLayout()
        configLayout()
    }
}

class GameListViewController : UICollectionViewController, GameViewControllerSaver {
    
    let path: String
    var gamesInProgress: Set<String>
    
    init(frame: CGRect) {
        let layout = GameListViewCollectionLayout(display: .list, collectionWidth: frame.width)
        self.path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        self.gamesInProgress = Set()
        super.init(collectionViewLayout: layout);
        if #available(iOS 13.0, *) {
            collectionView.backgroundColor = .systemGroupedBackground
        } else {
            collectionView.backgroundColor = .lightGray
        }
        self.title = "Puzzle"
        self.gamesInProgress = Set<String>()
        let files: [String]
        do {
            try files = FileManager.default.contentsOfDirectory(atPath: path)
        } catch {
            files = []
        }
        for fn in files {
            if (fn.hasSuffix(".save")) {
                let gameName = fn[fn.startIndex..<(fn.lastIndex(of: ".")!)]
                gamesInProgress.insert(String(gameName))
            }
        }
    }
    
    func saveGameViewController() -> GameViewController? {
        let lastGame = UserDefaults.standard.string(forKey: "lastgame")
        if (lastGame != nil) {
            var i = Int(gamecount) - 1
            while (i >= 0) {
                let gameName = String(cString: (swift_gamelist![i]!.pointee as game).name)
                if (gameName == lastGame) {
                    break
                }
                i -= 1
            }
            if (i >= 0) {
                return gameViewControllerForGame(game: swift_gamelist![i]!)
            }
        }
        return nil
    }
    
    func gameViewControllerForGame(game: UnsafePointer<game>) -> GameViewController {
        let inProgress: Bool
        let name = game.pointee.name
        var saved: String?
        do {
            try saved = String(contentsOfFile: "\(path)/\(String(cString: name!)).save", encoding: .utf8)
            inProgress = true
        } catch {
            inProgress = false
            do {
                try saved = String(contentsOfFile: "\(path)/\(String(cString: name!)).new", encoding: .utf8)
            } catch {
                saved = nil
            }
        }
        return GameViewController(game: game, saved: saved, inProgress: inProgress, saver: self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.register(GameListViewCell.self, forCellWithReuseIdentifier: "Cell")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UserDefaults.standard.removeObject(forKey: "lastgame")
        collectionView.reloadData()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        reloadCollectionViewLayout(view.bounds.width)
    }
    
    func reloadCollectionViewLayout(_ width: CGFloat) {
        (self.collectionViewLayout as! GameListViewCollectionLayout).containerWidth = width
        if (traitCollection.horizontalSizeClass == .compact) {
            (self.collectionViewLayout as! GameListViewCollectionLayout).display = .list
        } else {
            (self.collectionViewLayout as! GameListViewCollectionLayout).display = .grid(column: Int(width) / 250 )
        }
    }
    
    func saveGame(name: String, state: String, inProgress: Bool) {
        if (inProgress) {
            gamesInProgress.insert(name)
        } else {
            gamesInProgress.remove(name)
        }
        do {
            try state.write(toFile: "\(path)/\(name)\(inProgress ? ".save" : ".new")", atomically: true, encoding: .utf8)
        } catch {
            
        }
        if (!inProgress) {
            do {
                try FileManager.default.removeItem(atPath: "\(path)/\(name).save")
            } catch {
                
            }
        }
    }
    
    func showHelp() {
        navigationController?.pushViewController(GameHelpController(file: "help.html"), animated: true)
    }
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return Int(gamecount)
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath)
        let label = cell.viewWithTag(1) as! UILabel
        let image = cell.viewWithTag(2) as! UIImageView
        let detail = cell.viewWithTag(3) as! UILabel
        let inProgress = cell.viewWithTag(4) as! UIImageView
        let name = String(cString: swift_gamelist[indexPath.row]!.pointee.name)
        label.text = name
        detail.text = gameDescriptions[name]
        var iconName = name.replacingOccurrences(of: " ", with: "").lowercased()
        if (iconName == "rectangles") {
            iconName = "rect"
        }
            
        iconName.append("-96d24.png")
        image.image = UIImage(named: iconName)
        inProgress.isHidden = gamesInProgress.contains(name)
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let game = swift_gamelist[indexPath.row]
        let name = String(cString: game!.pointee.name)
        let gvc = gameViewControllerForGame(game: swift_gamelist[indexPath.row]!)
        navigationController?.pushViewController(gvc, animated: true)
        UserDefaults.standard.set(name, forKey: "lastgame")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
