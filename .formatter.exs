# Used by "mix format"
[
  plugins: [Phoenix.LiveView.HTMLFormatter, Styler],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: [attr: 3]
]
