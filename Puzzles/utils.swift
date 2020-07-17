//
//  utils.swift
//  Puzzles
//
//  Created by Duncan MacGregor on 18/03/2020.
//  Copyright © 2020 Greg Hewgill. All rights reserved.
//

import Foundation
import UIKit

func attach_timer(fe: UnsafePointer<frontend>) -> Void {
    let ptr = fe.pointee.gv
    let gv: GameView = bridge(ptr: ptr!)
    gv.activateTimer()
}

func detach_timer(fe: UnsafePointer<frontend>) -> Void {
    let ptr = fe.pointee.gv
    let gv: GameView = bridge(ptr: ptr!)
    gv.deactivateTimer()
}

func frontendDefaultColour(fe: UnsafeMutablePointer<frontend>?, output: UnsafeMutablePointer<Float>?) -> Void {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    let color: UIColor
    
    if #available(iOS 13.0, *) {
        color = UIColor.secondarySystemBackground
    } else {
        color = UIColor.lightGray
    }
    color.getRed(&red, green: &green, blue: &blue, alpha: nil)
    output?[0] = Float(red);
    output?[1] = Float(green);
    output?[2] = Float(blue);
}

func frontendDefaultColourFor(fe: UnsafeMutablePointer<frontend>?, output: UnsafeMutablePointer<Float>?, logicalColour: Int) -> Bool {
    let gv: GameView = bridge(ptr: (fe?.pointee.gv)!)
    let dark: Bool
    let foreground: UIColor
    let background: UIColor
    if #available(iOS 13.0, *) {
        dark = gv.traitCollection.userInterfaceStyle == .dark
        foreground = UIColor.label
        background = UIColor.secondarySystemBackground
    } else {
        dark = false
        foreground = UIColor.black
        background = UIColor.lightGray
    }
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    let colour: UIColor
    var foundColour = true
    switch(logicalColour) {
    case LOGICAL_BLACK:
        colour = UIColor.black
    case LOGICAL_WHITE:
        colour = UIColor.white
    case LOGICAL_GRID:
        colour = UIColor(white: 0.4, alpha: 1)
    case LOGICAL_BACKGROUND:
        colour = background
    case LOGICAL_FOREGROUND,
         LOGICAL_RECT_LINE,
         LOGICAL_RECT_TEXT,
         LOGICAL_SOLO_CLUE:
        colour = foreground
    case LOGICAL_HIGHLIGHT:
        if (dark) {
            colour = UIColor.darkGray
        } else {
            colour = UIColor.white
        }
    case LOGICAL_LOWLIGHT:
        if (dark) {
            colour = UIColor.black
        } else {
            colour = UIColor.gray
        }
    case LOGICAL_MINES_BACKGROUND2:
        if #available(iOS 13.0, *) {
            colour =  UIColor.systemGray6
        } else {
            colour = UIColor.gray
        }
    case LOGICAL_PEARL_LINE,
         LOGICAL_GALAXIES_EDGE,
         LOGICAL_NET_WIRE:
        if #available(iOS 13.0, *) {
            if (dark) {
                colour = UIColor.systemGray
            } else {
                colour = UIColor.black
            }
        } else {
            return frontendDefaultColourFor(fe: fe, output: output, logicalColour: LOGICAL_FOREGROUND)
        }
    case LOGICAL_PEARL_ERROR,
         LOGICAL_LIGHTUP_ERROR,
         LOGICAL_SOLO_ERROR,
         LOGICAL_NET_BARRIER,
         LOGICAL_NET_ERR:
        colour = UIColor.systemRed
    case LOGICAL_PEARL_DRAGON:
        colour = UIColor.systemBlue
    case LOGICAL_PEARL_DRAGOFF:
        if (dark) {
            colour = UIColor(red: 0.2, green: 0.2, blue: 0.4, alpha: 1)
        } else {
            colour = UIColor(red: 0.8, green: 0.8, blue: 1.0, alpha: 1)
        }
    case LOGICAL_LIGHTUP_LIGHT,
         LOGICAL_LIGHTUP_LABEL:
        return frontendDefaultColourFor(fe: fe, output: output, logicalColour: LOGICAL_WHITE)
    case LOGICAL_LIGHTUP_OUTLINE:
        colour = UIColor.black
    case LOGICAL_LIGHTUP_LIT:
        colour = UIColor(red: 1, green: 0.8, blue: 0, alpha: 1)
    case LOGICAL_LIGHTUP_WALL:
        if (dark) {
            colour = UIColor.darkGray
        } else {
            colour = UIColor.black
        }
    case LOGICAL_LIGHTUP_MARK:
        colour = UIColor.black
    case LOGICAL_LIGHTUP_CURSER,
         LOGICAL_GALAXIES_CURSOR,
         LOGICAL_RECT_CURSOR:
        if (dark) {
            colour = UIColor(white: 0.4, alpha: 1)
        } else {
            colour = UIColor(white: 0.6, alpha: 1)
        }
    case LOGICAL_NET_LOCKED:
        colour = UIColor.lightGray
    case LOGICAL_NET_ENDPOINT:
        colour = UIColor.blue
    case LOGICAL_NET_POWERED:
        colour = UIColor.cyan
    case LOGICAL_GALAXIES_WHITEBG:
        if #available(iOS 13.0, *) {
            colour = UIColor.systemGray2
        } else {
            colour = UIColor.white
        }
    case LOGICAL_GALAXIES_BLACKBG:
        colour = UIColor.black
    case LOGICAL_GALAXIES_WHITEDOT:
        colour = UIColor.white
    case LOGICAL_GALAXIES_BLACKDOT:
        colour = UIColor.black
    case LOGICAL_GALAXIES_ARROW:
        return frontendDefaultColourFor(fe: fe, output: output, logicalColour: LOGICAL_FOREGROUND)
    case LOGICAL_RECT_DRAG:
        colour = UIColor.systemRed
    case LOGICAL_RECT_DRAGERASE:
        colour = UIColor.systemBlue
    case LOGICAL_GUESS_EMPTY,
         LOGICAL_RECT_CORRECT,
         LOGICAL_SOLO_HIGHLIGHT:
        if #available(iOS 13.0, *) {
            colour = UIColor.systemGray3
        } else {
            colour = UIColor.lightGray
        }
    case LOGICAL_SOLO_DIAGONALS:
        if #available(iOS 13.0, *) {
            colour = UIColor.systemGray5
        } else {
            colour = UIColor.lightGray
        }
    case LOGICAL_SOLO_USER:
        colour = UIColor.systemGreen
    case LOGICAL_SOLO_PENCIL:
        colour = UIColor.systemBlue
    case LOGICAL_SOLO_KILLER:
        colour = UIColor.systemOrange
    case LOGICAL_MINES_1:
        colour = UIColor.systemBlue
    case LOGICAL_MINES_2:
        colour = UIColor.systemGreen
    case LOGICAL_MINES_3:
        colour = UIColor.systemRed
    case LOGICAL_MINES_4:
        colour = blend(first: UIColor.systemBlue, second: foreground, factor: 0.5)
    case LOGICAL_MINES_5:
        colour = blend(first: UIColor.systemGreen, second: foreground, factor: 0.5)
    case LOGICAL_MINES_6:
        colour = blend(first: UIColor.systemRed, second: foreground, factor: 0.5)
    case LOGICAL_MINES_7:
        colour = blend(first: UIColor.systemTeal, second: foreground, factor: 0.5)
    case LOGICAL_MINES_8:
        colour = foreground
    case LOGICAL_MINES_MINE:
        colour = UIColor.black
    case LOGICAL_MINES_BANG,
         LOGICAL_MINES_CROSS,
         LOGICAL_MINES_FLAG:
        colour = UIColor.systemRed
    case LOGICAL_MINES_WRONGNUMBER,
         LOGICAL_MINES_CURSOR:
        colour = blend(first: background, second: UIColor.systemRed, factor: 0.5)
    default:
        colour = UIColor.magenta
        foundColour = false
    }
    colour.getRed(&red, green: &green, blue: &blue, alpha: nil)
    output?[0] = Float(red);
    output?[1] = Float(green);
    output?[2] = Float(blue);
    return foundColour
}

func blend(first: UIColor, second: UIColor,  factor: CGFloat) -> UIColor {
    var r1 :CGFloat = 0.0, g1 :CGFloat = 0.0, b1 :CGFloat = 0.0, a1 :CGFloat = 0.0
    var r2 :CGFloat = 0.0, g2 :CGFloat = 0.0, b2 :CGFloat = 0.0, a2 :CGFloat = 0.0
    first.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
    second.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
    let resComps = zip([r1, g1, b1, a1], [r2, g2, b2, a2]).map { $0 * factor + $1 * (1.0-factor)}
    
    return UIColor(red: resComps[0], green: resComps[1], blue: resComps[2], alpha: resComps[3])
}
