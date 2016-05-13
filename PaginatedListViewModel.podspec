Pod::Spec.new do |s|

  s.name         = "PaginatedListViewModel"
  s.version      = "0.0.2"
  s.summary      = "RAC-based lightweight generic ViewModel to handle paginated lists of items, with pages retrieved asynchronously."

  s.description  = <<-DESC
RAC-based lightweight generic ViewModel to handle paginated lists of items (with pages retrieved asynchronously, typically, but not necessarily, from from REST APIs)
swift 2.1 compatible  
                 DESC

  s.homepage     = "https://github.com/gavrix/PaginatedListViewModel"
  s.license      = { :type => "MIT", :file => "LICENSE" }

  s.author             = { "Sergey Gavrilyuk" => "sergey.gavrilyuk@gmail.com" }
  s.social_media_url   = "http://twitter.com/octogavrix"

  s.platform     = :ios, "8.0"
  s.framework  = "Foundation"

  s.source       = { :git => "https://github.com/gavrix/PaginatedListViewModel.git", :tag => "#{s.version}" }
  s.source_files  = "PaginatedListViewModel/PaginatedListViewModel/**/*.swift"


  s.dependency "Result", "~> 2.0"
  s.dependency "ReactiveCocoa", "~> 4.1"

end
