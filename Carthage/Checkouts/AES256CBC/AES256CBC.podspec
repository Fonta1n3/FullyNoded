Pod::Spec.new do |s|
  s.name         = "AES256CBC"
  s.version      = "1.3.1"
  s.summary      = "Most convenient AES256-CBC encryption for Swift 2, 3 & 4"

  # This description is used to generate tags and improve search results.
  #   * Think: What does it do? Why did you write it? What is the focus?
  #   * Try to keep it short, snappy and to the point.
  #   * Write the description between the DESC delimiters below.
  #   * Finally, don't worry about the indent, CocoaPods strips it!
  s.description  = <<-DESC
  AES256 is the most convenient, simple & leightweight Swift 2 & 3 framework to encrypt & decrypt a string with AES256-CBC encryption. Tag 1.x.x is using Swift 3 and tag 0.1.1 is using Swift 2. The project is actively maintained by SwiftyBeaver (Twitter: @SwiftyBeaver).
                   DESC

  s.homepage     = "https://github.com/SwiftyBeaver/AES256CBC"
  s.license      = "MIT"
  s.author       = { "Sebastian Kreutzberger" => "s.kreutzberger@googlemail.com" }
  s.ios.deployment_target = "8.0"
  s.watchos.deployment_target = "2.0"
  s.tvos.deployment_target = "9.0"
  s.osx.deployment_target = "10.9"
  s.source       = { :git => "https://github.com/SwiftyBeaver/AES256CBC.git", :tag => "1.3.1" }
  s.source_files  = "sources"
end

