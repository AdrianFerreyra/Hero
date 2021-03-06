//
//  HeroDebugPlugin.swift
//  Pods
//
//  Created by Luke Zhao on 2016-12-13.
//
//

import UIKit

public class HeroDebugPlugin: HeroPlugin {
  var interactiveContext:HeroInteractiveContext?
  var debugView:HeroDebugView?
  var zPositionMap = [UIView:CGFloat]()

  override public func wantInteractiveHeroTransition(context: HeroInteractiveContext) -> Bool {
    interactiveContext = context
    return true
  }

  override public func animate(context: HeroContext, fromViews: [UIView], toViews: [UIView]) -> TimeInterval {
    guard let interactiveContext = interactiveContext else { return 0 }
    
    debugView = HeroDebugView(initialProcess: interactiveContext.presenting ? 0.0 : 1.0)
    debugView!.frame = interactiveContext.container.bounds
    debugView!.delegate = self
    UIApplication.shared.keyWindow!.addSubview(debugView!)

    context.container.backgroundColor = UIColor(white: 0.85, alpha: 1.0)
    
    debugView!.layoutSubviews()
    UIView.animate(withDuration: 0.4){
      self.debugView!.showControls = true
    }
    return 0
  }

  public override func resume(from progress: Double, reverse: Bool) -> TimeInterval {
    guard interactiveContext != nil, let debugView = debugView else { return 0.4 }
    debugView.delegate = nil
    
    UIView.animate(withDuration: 0.4){
      debugView.showControls = false
      debugView.debugSlider.setValue(roundf(debugView.progress), animated: true)
    }

    on3D(wants3D: false)
    return 0.4
  }
  
  public override func clean() {
    interactiveContext = nil
    debugView?.removeFromSuperview()
    debugView = nil
  }
}

extension HeroDebugPlugin:HeroDebugViewDelegate{
  public func onDone() {
    guard let interactiveContext = interactiveContext, let debugView = debugView else { return }
    let seekValue = interactiveContext.presenting ? debugView.progress : 1.0 - debugView.progress
    if seekValue > 0.5 {
      interactiveContext.end()
    } else {
      interactiveContext.cancel()
    }
  }

  public func onProcessSliderChanged(progress:Float){
    guard let interactiveContext = interactiveContext else { return }
    let seekValue = interactiveContext.presenting ? progress : 1.0 - progress
    interactiveContext.update(progress: Double(seekValue))
  }

  func onPerspectiveChanged(translation:CGPoint, rotation: CGFloat, scale:CGFloat) {
    guard let interactiveContext = interactiveContext else { return }
    var t = CATransform3DIdentity
    t.m34 = -1 / 4000
    t = CATransform3DTranslate(t, translation.x, translation.y, 0)
    t = CATransform3DScale(t, scale, scale, 1)
    t = CATransform3DRotate(t, rotation, 0, 1, 0)
    interactiveContext.container.layer.sublayerTransform = t
  }
  
  func animateZPosition(view:UIView, to:CGFloat){
    let a = CABasicAnimation(keyPath: "zPosition")
    a.fromValue = view.layer.value(forKeyPath: "zPosition")
    a.toValue = NSNumber(value: Double(to))
    a.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
    a.duration = 0.4
    view.layer.add(a, forKey: "zPosition")
    view.layer.zPosition = to
  }

  func on3D(wants3D: Bool) {
    guard let interactiveContext = interactiveContext else { return }
    var t = CATransform3DIdentity
    if wants3D{
      var viewsWithZPosition = Set<UIView>()
      for view in interactiveContext.container.subviews{
        if view.layer.zPosition != 0{
          viewsWithZPosition.insert(view)
          zPositionMap[view] = view.layer.zPosition
        }
      }

      let viewsWithoutZPosition = interactiveContext.container.subviews.filter{ return !viewsWithZPosition.contains($0) }
      let viewsWithPositiveZPosition = viewsWithZPosition.filter{ return $0.layer.zPosition > 0 }
      
      for (i, v) in viewsWithoutZPosition.enumerated(){
        animateZPosition(view:v, to:CGFloat(i * 10))
      }
      
      var maxZPosition:CGFloat = 0
      for v in viewsWithPositiveZPosition{
        maxZPosition = max(maxZPosition, v.layer.zPosition)
        animateZPosition(view:v, to:v.layer.zPosition + CGFloat(viewsWithoutZPosition.count * 10))
      }
      
      t.m34 = -1 / 4000
      t = CATransform3DTranslate(t, debugView!.translation.x, debugView!.translation.y, 0)
      t = CATransform3DScale(t, debugView!.scale, debugView!.scale, 1)
      t = CATransform3DRotate(t, debugView!.rotation, 0, 1, 0)
    } else {
      for v in interactiveContext.container.subviews{
        animateZPosition(view:v, to:self.zPositionMap[v] ?? 0)
      }
      self.zPositionMap.removeAll()
    }
    
    let a = CABasicAnimation(keyPath: "sublayerTransform")
    a.fromValue = interactiveContext.container.layer.value(forKeyPath: "sublayerTransform")
    a.toValue = NSValue(caTransform3D: t)
    a.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
    a.duration = 0.4
    
    interactiveContext.container.layer.add(a, forKey: "debug")
    interactiveContext.container.layer.sublayerTransform = t
  }
}
