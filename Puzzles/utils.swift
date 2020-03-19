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

func frontendDefaultColourFor(fe: UnsafeMutablePointer<frontend>, colour: Int, output: UnsafeMutablePointer<Float>) -> Bool {
    return false
}
