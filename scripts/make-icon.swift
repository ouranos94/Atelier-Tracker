import AppKit
let destination = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath:destination,withIntermediateDirectories:true)
for size in [16,32,128,256,512] {
    for scale in [1,2] {
        let pixels = size*scale
        let image = NSImage(size:NSSize(width:pixels,height:pixels))
        image.lockFocus()
        let p = CGFloat(pixels)
        NSColor(red:0.055,green:0.07,blue:0.10,alpha:1).setFill()
        NSBezierPath(roundedRect:NSRect(x:p*0.06,y:p*0.06,width:p*0.88,height:p*0.88),xRadius:p*0.20,yRadius:p*0.20).fill()
        let colors: [NSColor] = [.init(red:0.42,green:0.94,blue:0.76,alpha:1),.init(red:0.65,green:0.61,blue:1,alpha:1),.init(red:1,green:0.72,blue:0.43,alpha:1),.init(red:0.45,green:0.75,blue:1,alpha:1)]
        for i in 0..<4 {for j in 0..<5 {
            colors[i].withAlphaComponent([0.25,0.5,1,0.5,0.25][(j+i)%5]).setFill()
            NSBezierPath(roundedRect:NSRect(x:p*(0.23+Double(i)*0.145),y:p*(0.23+Double(j)*0.115),width:p*0.10,height:p*0.075),xRadius:p*0.017,yRadius:p*0.017).fill()
        }}
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data:image.tiffRepresentation!)!
        let name = "icon_\(size)x\(size)" + (scale == 2 ? "@2x" : "") + ".png"
        try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:destination).appendingPathComponent(name))
    }
}
