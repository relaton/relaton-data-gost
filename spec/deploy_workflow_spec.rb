# frozen_string_literal: true

require "yaml"

# Guards the caller contract of .github/workflows/deploy.yml. The workflow only
# ever runs on GitHub, so a wrong input name or a dropped trigger would surface
# as a red Pages build days later. No CI job in this repo runs rspec, so this is
# a local guard — run it by hand when touching the workflow.
RSpec.describe "Deploy workflow" do # rubocop:disable RSpec/DescribeClass
  subject(:workflow) { YAML.safe_load_file(path, aliases: true) }

  # Inputs declared by relaton/support/.github/workflows/data-deploy.yml.
  # Anything outside this set makes the reusable-workflow call invalid.
  let(:shared_workflow_inputs) do
    %w[
      source title favicon description data-dir mode
      relaton-cli-version relaton-repo relaton-ref
    ]
  end

  let(:path) { File.expand_path("../.github/workflows/deploy.yml", __dir__) }
  let(:deploy) { workflow.fetch("jobs").fetch("deploy") }
  let(:inputs) { deploy.fetch("with") }

  # Psych follows YAML 1.1, where the bare key `on:` is the boolean true — the
  # GitHub Actions trigger block therefore lands under `true`, not "on".
  let(:triggers) { workflow.fetch(true) }

  it "is present" do
    expect(File).to exist(path)
  end

  it "calls relaton/support's shared reusable workflow" do
    expect(deploy.fetch("uses"))
      .to eq("relaton/support/.github/workflows/data-deploy.yml@main")
  end

  it "passes only inputs the shared workflow declares" do
    expect(inputs.keys - shared_workflow_inputs).to be_empty
  end

  # Temporary: no released relaton-cli ships the `index` command yet, so the
  # default `source: gem` would fail. Drop the pin once one does.
  it "pilots the git source" do
    expect(inputs.fetch("source")).to eq("git")
  end

  it "carries the GOST branding from support's data-index config" do
    expect(inputs.fetch("favicon")).to eq("https://www.relaton.org/favicon.ico")
    expect(inputs.fetch("description")).to match(/GOST standards index site/)
  end

  # The shared workflow derives "<FLAVOR> Index" from the repo name, which is
  # already "GOST Index" here — passing title: would only risk drifting from it.
  it "leaves the title to the shared workflow's derivation" do
    expect(inputs).not_to have_key("title")
  end

  it "builds on pushes to the default branch" do
    expect(triggers.fetch("push").fetch("branches")).to include("main")
  end

  # The reusable workflow's deploy job only publishes when the ref is the
  # default *branch*, so a tag build would compile everything and publish
  # nothing — same reasoning as the missing pull_request trigger below.
  it "does not build on release tags" do
    expect(triggers.fetch("push")).not_to have_key("tags")
  end

  # Pages permits one in-flight deployment; overlapping runs otherwise fail.
  it "serialises Pages deployments" do
    expect(workflow.fetch("concurrency"))
      .to eq("group" => "pages", "cancel-in-progress" => false)
  end

  it "rebuilds daily, after the crawler's 14:00 UTC run" do
    crons = triggers.fetch("schedule").map { |entry| entry.fetch("cron") }
    expect(crons).to eq(["0 15 * * *"])
  end

  it "can be triggered by hand" do
    expect(triggers).to have_key("workflow_dispatch")
  end

  # data/ holds tens of thousands of documents and the deploy job never
  # publishes from a pull request, so a per-PR index build buys nothing.
  it "does not build on pull requests" do
    expect(triggers).not_to have_key("pull_request")
  end
end
