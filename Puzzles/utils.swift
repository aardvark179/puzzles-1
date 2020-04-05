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
    if #available(iOS 13.0, *) {
        dark = gv.traitCollection.userInterfaceStyle == .dark
    } else {
        dark = false
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
        if #available(iOS 13.0, *) {
            colour =  UIColor.secondarySystemBackground
        } else {
            colour = UIColor.lightGray
        }
    case LOGICAL_FOREGROUND:
        if #available(iOS 13.0, *) {
            colour = UIColor.label
        } else {
            colour = UIColor.black
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
         LOGICAL_GALAXIES_CURSOR:
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
            if (dark) {
                colour = UIColor.systemGray2
            } else {
                colour = UIColor.white
            }
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
    default:
        colour = UIColor.systemGreen
        foundColour = false
    }
    colour.getRed(&red, green: &green, blue: &blue, alpha: nil)
    output?[0] = Float(red);
    output?[1] = Float(green);
    output?[2] = Float(blue);
    return foundColour
}
