//
//  WKWebView+KeitaiWaniKani.swift
//  KeitaiWaniKani
//
//  Copyright © 2015 Chris Laverty. All rights reserved.
//

import WebKit

private var swizzledClassMapping: [AnyClass] = []

extension WKWebView {
    // Adapted from http://stackoverflow.com/questions/19033292/ios-7-uiwebview-keyboard-issue?lq=1
    func noInputAccessoryView() -> UIView? {
        return nil
    }
    
    func removeInputAccessoryView() {
        guard let subview = scrollView.subviews.filter({ NSStringFromClass($0.dynamicType).hasPrefix("WKContent") }).first else {
            return
        }
        
        // Guard in case this method is called twice on the same webview.
        guard !(swizzledClassMapping as NSArray).containsObject(subview.dynamicType) else {
            return
        }
        
        let className = "\(subview.dynamicType)_SwizzleHelper"
        var newClass: AnyClass? = NSClassFromString(className)
        
        if newClass == nil {
            newClass = objc_allocateClassPair(subview.dynamicType, className, 0)
            
            guard newClass != nil else {
                return
            }
            
            let method = class_getInstanceMethod(self.dynamicType, #selector(noInputAccessoryView))
            class_addMethod(newClass!, Selector("inputAccessoryView"), method_getImplementation(method), method_getTypeEncoding(method))
            
            objc_registerClassPair(newClass!)
            
            swizzledClassMapping += [newClass!]
        }
        
        object_setClass(subview, newClass!)
    }
    
    // http://stackoverflow.com/questions/28631317/how-to-disable-scrolling-entirely-in-a-wkwebview
    func setScrollEnabled(enabled: Bool) {
        self.scrollView.scrollEnabled = enabled
        self.scrollView.panGestureRecognizer.enabled = enabled
        self.scrollView.bounces = enabled
        
        for subview in self.subviews {
            if let subview = subview as? UIScrollView {
                subview.scrollEnabled = enabled
                subview.bounces = enabled
                subview.panGestureRecognizer.enabled = enabled
            }
            
            for subScrollView in subview.subviews {
                if subScrollView.dynamicType == NSClassFromString("WKContentView")! {
                    for gesture in subScrollView.gestureRecognizers! {
                        subScrollView.removeGestureRecognizer(gesture)
                    }
                }
            }
        }
    }
    
    func scrollToTop(animated: Bool) {
        self.scrollView.setContentOffset(CGPoint(x: 0, y: -self.scrollView.contentInset.top), animated: animated)
    }
    
    // Adapted from https://github.com/Telerik-Verified-Plugins/WKWebView/commit/04e8296adeb61f289f9c698045c19b62d080c7e3
    func keyboardDisplayDoesNotRequireUserAction() {
        typealias SelectorImpType = @convention(c) (AnyObject!, Selector, objc_objectptr_t, CBool, CBool, AnyObject?) -> Void
        
        let sel = sel_getUid("_startAssistingNode:userIsInteracting:blurPreviousNode:userObject:")
        let WKContentView: AnyClass? = NSClassFromString("WKContentView")
        let method = class_getInstanceMethod(WKContentView, sel)
        let originalImp = method_getImplementation(method)
        let block: @convention(block) (AnyObject!, objc_objectptr_t, CBool, CBool, AnyObject?) -> Void = {
            let chained = unsafeBitCast(originalImp, SelectorImpType.self)
            chained($0, sel, $1, true, $3, $4)
        }
        let imp = imp_implementationWithBlock(unsafeBitCast(block, AnyObject.self))
        method_setImplementation(method, imp)
    }
}