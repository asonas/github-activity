#!/usr/bin/env ruby
require "bundler/setup"

Bundler.require

Octokit.configure do |c|
  c.api_endpoint = ENV["GITHUB_API_ENDPOINT"]
end

client = Octokit::Client.new(access_token: ENV["GITHUB_ACCESS_TOKEN"])
n = Time.now
today = (Time.utc(n.year,n.month,n.day,0,0,0)..Time.utc(n.year,n.month,n.day+1,8,59,59))

events = client.get("users/asonas/events?per_page=100").select do |event|
  today.include? event.created_at
end

Activity = Data.define(:repo, :url, :title, :state, :type)

activities = events.reverse.map do |event|
  case event.type
  when "PullRequestEvent"
    state =
      if event.payload.pull_request.state == "closed"
        if event.payload.pull_request.merged_at
          "merged"
        else
          event.payload.pull_request.state
        end
      else
        event.payload.pull_request.state
      end
    Activity.new(
      repo: event.payload.pull_request.base.repo.full_name,
      url: event.payload.pull_request.html_url,
      title: event.payload.pull_request.title,
      state: state,
      type: event.type
    )
  when "PullRequestReviewEvent"
    # ignore
    #Activity.new(
    #  repo: event.payload.pull_request.base.repo.full_name,
    #  url: event.payload.review.html_url,
    #  title: event.payload.pull_request.title,
    #  state: event.payload.review.state,
    #  type: event.type
    #)
  when "IssuesEvent"
    Activity.new(
      repo: event.payload.issue.repository_url.split("/")[-2..].join("/"),
      url: event.payload.issue.html_url,
      title: event.payload.issue.title,
      state: event.payload.issue.state,
      type: event.type
    )
  when "PullRequestReviewCommentEvent"
    Activity.new(
      repo: event.payload.pull_request.base.repo.full_name,
      url: event.payload.comment.html_url,
      title: event.payload.comment.body.gsub(/[\r\n]/,"")[0..30] + "...",
      state: "comment",
      type: event.type
    )
  when "CreateEvent", "DeleteEvent", "PushEvent"
    # nanimoshinai
  else
    puts event.type
  end
end.compact

emoji = {
  "merged" => ":check_mark_button:",
  "closed" => ":closed_book:",
  "open" => ":open_book:",
  "comment" => ":memo:",
}

template = ERB.new <<EOF
## GitHub Activity
<% activities.each do |act| %>
- <%= emoji[act.state] %> **<%= act.repo %>**: [<%= act.title%>](<%= act.url%>)<% end %>
EOF

puts template.result
