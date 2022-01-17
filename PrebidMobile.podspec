{
  "name": "YieldlovePrebidMobile",
  "version": "2.1.0",
  "summary": "PrebidMobile is a lightweight framework that integrates directly with Prebid Server.",
  "description": "Prebid-Mobile-SDK is a lightweight framework that integrates directly with Prebid Server to increase yield for publishers by adding more mobile buyers.\"",
  "homepage": "https://www.prebid.org",
  "license": {
    "type": "Apache License, Version 2.0",
    "text": "    Copyright 2018-2021 Prebid.org, Inc.\n\n    Licensed under the Apache License, Version 2.0 (the \"License\");\n    you may not use this file except in compliance with the License.\n    You may obtain a copy of the License at\n\n    http://www.apache.org/licenses/LICENSE-2.0\n\n    Unless required by applicable law or agreed to in writing, software\n    distributed under the License is distributed on an \"AS IS\" BASIS,\n    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.\n    See the License for the specific language governing permissions and\n    limitations under the License.\n"
  },
  "authors": {
    "Prebid.org, Inc.": "info@prebid.org"
  },
  "platforms": {
    "ios": "10.0"
  },
  "swift_versions": "5.0",
  "source": {
    "git": "https://github.com/yieldlove/prebid-mobile-ios.git",
    "tag": "1.12-content-url"
  },
  "xcconfig": {
    "LIBRARY_SEARCH_PATHS": "$(inherited)",
    "OTHER_CFLAGS": "$(inherited)",
    "OTHER_LDFLAGS": "$(inherited)",
    "HEADER_SEARCH_PATHS": "$(inherited)",
    "FRAMEWORK_SEARCH_PATHS": "$(inherited)"
  },
  "frameworks": [
    "CoreTelephony",
    "SystemConfiguration",
    "UIKit",
    "Foundation"
  ],
  "module_name": "PrebidMobile",
  "default_subspecs": "core",
  "subspecs": [
    {
      "name": "core",
      "source_files": "PrebidMobile/**/*.{h,m,swift}"
    }
  ],
  "swift_version": "5.0"
}