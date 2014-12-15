<html>
	<head>
		<title><%= opts[:title] %></title>
		<link rel="stylesheet" href="./style.css" />
		<meta charset="UTF-8" />
	</head>

	<body>
		<div class="row">
			<div class="container">
				<nav class="u-pull-right four columns">
					<div id="docs-aside">
						<ul id="docs-aside" class="nav">
							<%= for {key, val} <- sitemap do %>
								<li class="active">
									<a href="#<%= key %>"><%= val.title || key %></a>
									<ul class="nav">
										<%= for {key, val} <- val[:children] do %>
											<li><a class="block-link" href="#<%= val.link %>"><%= val.title || key%></a></li>
										<% end %>
									</ul>
								</li>
							<% end %>
						</ul>
						<a class="back-to-top" href="#top">Back to top</a>
					</div>
				</nav>

				<div id="content" class="eight columns">
					<%= for doc <- docs do %>
						<%= for block <- doc, do: block.text %>
					<% end %>
				</div>
			</div>
		</div>
		<footer class="docs-footer" role="contentinfo">
		<div class="container">
			<p>
				Designed, built and powered by awesome open source projects including
					<a href="http://getskeleton.com/">Skeleton</a>,
					<a href="https://github.com">GitHub</a> and
					<a href="https://elixir-lang.org/">Elixir</a>
			</p>

			<ul class="docs-footer-links muted">
				<li><b>Versions</b></li>
				<%= for vsn <- versions do %>
					<%= if vsn === vsn do %>
						<li class="active"><a href="../<%= vsn %>"><%= vsn %></a></li>
					<% else %>
						<li class="active"><a href="../<%= vsn %>"><%= vsn %></a></li>
					<% end %>
				<% end %>
			</ul>
		</div>
		</footer>
	</body>
</html>
