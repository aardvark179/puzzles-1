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
    switch(logicalColour) {
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
    case LOGICAL_PEARL_LINE:
        if #available(iOS 13.0, *) {
            if (dark) {
                colour = UIColor.systemGray2
            } else {
                colour = UIColor.black
            }
        } else {
            return frontendDefaultColourFor(fe: fe, output: output, logicalColour: LOGICAL_FOREGROUND)
        }
    case LOGICAL_PEARL_ERROR:
        colour = UIColor.systemRed
    case LOGICAL_PEARL_DRAGON:
        colour = UIColor.systemBlue
    case LOGICAL_PEARL_DRAGOFF:
        if (dark) {
            colour = UIColor(red: 0.2, green: 0.2, blue: 0.4, alpha: 1)
        } else {
            colour = UIColor(red: 0.8, green: 0.8, blue: 1.0, alpha: 1)
        }
    default:
        colour = UIColor.systemGreen
    }
    colour.getRed(&red, green: &green, blue: &blue, alpha: nil)
    output?[0] = Float(red);
    output?[1] = Float(green);
    output?[2] = Float(blue);
    return true
}
