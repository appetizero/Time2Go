import WidgetKit
import SwiftUI

@main
struct Time2GoWidgets: WidgetBundle {
    var body: some Widget {
        Time2GoWidget()        // 你原来的 Widget
        Time2GoLiveActivity()  // 新增的 Live Activity
    }
}
