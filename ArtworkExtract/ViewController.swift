//
//  ViewController.swift
//  ArtworkExtract
//
//  Created by Florian Pichler on 19.02.19.
//  Copyright © 2019 Florian Pichler. All rights reserved.
//

import Cocoa
import ColorCube

func relativeDistance(color1: NSColor, color2: NSColor) -> CGFloat {
    var dist = fabs(Double(color1.hueComponent) - Double(color2.hueComponent))
    
    if (dist > 0.5) {
        dist = 1 - dist
    }
    
    return CGFloat(dist)
}

class ViewController: NSViewController {
    @IBOutlet weak var imageWell: NSImageView!
    @IBOutlet weak var container: NSView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override var representedObject: Any? {
        didSet {
        }
    }
    
    @IBAction func imageSelected(_ sender: NSImageView) {
        let colorCube = CCColorCube()
        
        guard let image = sender.image else { return }
        
        var colors: [NSColor] = colorCube.extractColors(from: image, flags: CCOnlyDistinctColors, count: 5)!
        
//        let colorCount = colors.count
        
        self.container.subviews.removeAll()
        
        let forbiddenColors: [String] = [
            // Neon yellows
            "#ecef2d",
            "#ecf02d",
            "#f0ea15",
            "#f0ea16",
            // old green
            "#77b54a",
        ]
        
        // Audible must die
        colors = colors.filter({ !forbiddenColors.contains($0.cssHex) })
        
        // Recalculate colors if no colors were removed.
        // Extracting less colors yields better results when it comes to contrast and distinctness
//        if !(colors.count < colorCount)  {
//            colors = colorCube.extractColors(from: image, flags: CCOnlyDistinctColors, count: 6)!
//        }

        // Average (used only for calculations, not for theme)
        
        let averageColor = image.averageColor()!
        
        colors.append(averageColor)
        
        // lightest color - defined by average of HSB brightness and HSL Luminance
    
        var lightestColor: NSColor = colors[0]
        
        for color in colors {
            let previousAverage = (lightestColor.brightness + lightestColor.luminance) / 2
            let brightnessLuminanceAverage = (color.brightness + color.luminance) / 2
            
            if (brightnessLuminanceAverage > previousAverage && color.saturation < lightestColor.saturation) {
                lightestColor = color
            }
        }
        
        // Background color
        
        var background = lightestColor.blended(withFraction: 0.1, of: averageColor)
        let bgThreshold: CGFloat = 0.7
        let maxThreshold: CGFloat = 0.95
        
        if background!.luminance < bgThreshold {
            background = background?.blended(withFraction: 0.5, of: NSColor.white)
        }
        
        if (background!.luminance > maxThreshold && background!.brightness > maxThreshold) {
            background = background?.blended(withFraction: 0.02, of: NSColor.black)
        }
        
        //  Ensure a lighter color for very saturated backgrounds
        let satuationThreshold: CGFloat = 0.9
        let brightnessThreshold: CGFloat = 0.9
        
        if (background?.saturation)! > satuationThreshold && (background?.brightness)! > brightnessThreshold {
            background = background?.blended(withFraction: 0.8, of: NSColor.white)!
        }
        
        self.view.layer?.backgroundColor = background?.cgColor
        
        colors = colors.filter{ $0 != background! }
        
        // Primary Color
        
        var primary = colors[0]
        
        for color in colors {
            if color.contrastRatio(with: background!) > primary.contrastRatio(with: background!) {
                primary = color
            }
        }
        
        if primary.contrastRatio(with: background!) < 2 {
            primary = primary.blended(withFraction: 0.88, of: NSColor.black)!
        }
        
        colors = colors.filter{ $0 != primary }
        
        // Secondary color
        
        var secondary = colors[0]
        let primaryBrightness = primary.brightness
        let backgroundBrightness = background!.brightness
        let targetBrightness = primaryBrightness * 0.4 + backgroundBrightness * 0.6
        
        for color in colors {
            if abs(color.brightness - targetBrightness) < abs(secondary.brightness - targetBrightness) {
                secondary = color
            }
        }
        
        colors = colors.filter{ $0 != secondary }
        
        // Highlight color
        
        var highlight = colors[0]
        
        for color in colors {
            let dist = relativeDistance(color1: background!, color2: color)
            let currentDist = relativeDistance(color1: background!, color2: highlight)
            
            // Prefer colors which are further away in hue and are more saturated
            if dist > currentDist && color.saturation > (background?.saturation)! {
                highlight = color
            }
        }
        
        // Display colors

        colors.append(background!)
        colors.append(primary)
        colors.append(secondary)
        colors.append(highlight)
        
        var currentRow = 0
        var currentColumn = 0
        
        colors.forEach { color in
            if (currentColumn > 3 || color == background) {
                currentRow += 1
                currentColumn = 0
            }
            
            let brightness = String(format: "%.2f", color.brightness)
            let luminance = String(format: "%.2f", color.luminance)
            let saturation = String(format: "%.2f", color.saturation)
            
            var type = ""
            
            if (color == averageColor) {
                type = "\nAverage"
            }
            
            if (color == lightestColor) {
                type = "\nLightest"
            }
            
            if (color == background) {
                type = "\nBackground"
            }
            
            if (color == primary) {
                type = "\nPrimary"
            }
            
            if (color == secondary) {
                type = "\nSecondary"
            }
            
            if (color == highlight) {
                type = "\nHighlight"
            }
            
            let contrast = String(format: "B %.2f Hue %.2f", color.contrastRatio(with: background!), color.hueComponent)
            
            let label: NSTextField = NSTextField.init(
                labelWithString: "\(color.cssHex)\nsaturation \(saturation)\nbrightness \(brightness)\nluminance \(luminance)\(type)\n\(contrast)"
            )
            
            label.frame = NSRect(x: 110 * currentColumn, y: 100 * currentRow, width: 100, height: 90)
            label.drawsBackground = true
            label.backgroundColor = color
            label.textColor = color.fullContrastColor
            label.isSelectable = true
            label.font = NSFont.systemFont(ofSize: 11)
            
            self.container.addSubview(label)
            
            currentColumn += 1
        }
    
    }
    
}
