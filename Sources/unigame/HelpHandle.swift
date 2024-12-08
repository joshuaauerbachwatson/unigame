/**
 * Copyright (c) 2021-present, Joshua Auerbach
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
import AuerbachLook

public protocol HelpHandle {
    // - The HTML for the table of contents for the app specific help
    // Each entry should be of the form
    // <li><a href="#SOME-TAG">SOME TEXT</a></li>
    var appSpecificTOC: String { get }

    // - The HTML for a brief general description of the app
    var generalDescription: String { get }
    
    // - The HTML contents for the app-specific section of the help
    var appSpecificHelp: String { get }
    
    // - The email address to which feedback should be sent.
    var email: String { get }
    
    // - The name to use when referring to the app.
    var appName: String { get }
    
    // - (optional) The TipResetter to invoke when the option to restore tips is selected.
    var tipResetter: TipResetter? { get }
}

// Placeholder for the case when the app does not provide help
struct NoHelpProvided: HelpHandle {
    var appSpecificTOC = ""
    
    var generalDescription = "No Help Provided for this App"
    
    var appSpecificHelp: String = "No Help Provided for this App"
    
    var email: String = "nobody@noplace.com"
    
    var appName: String = "Unknown"
    
    var tipResetter: (any AuerbachLook.TipResetter)? = nil
}
