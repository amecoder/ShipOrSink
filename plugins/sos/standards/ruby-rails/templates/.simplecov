# .simplecov — SimpleCov 설정 (Ruby 표준 커버리지 도구)
# Docs: https://github.com/simplecov-ruby/simplecov

# spec_helper.rb / test_helper.rb 최상단에 다음을 추가:
#   require "simplecov"
#   SimpleCov.start

require "simplecov-cobertura"   # coverage/coverage.xml for scripts/coverage-gate.sh (gem simplecov-cobertura)

SimpleCov.start "rails" do
  add_filter "/test/"
  add_filter "/spec/"
  add_filter "/config/"
  add_filter "/db/"
  add_filter "/vendor/"
  add_filter "/bin/"

  add_group "Models", "app/models"
  add_group "Controllers", "app/controllers"
  add_group "Services", "app/services"
  add_group "Workers", "app/workers"
  add_group "Jobs", "app/jobs"
  add_group "Mailers", "app/mailers"
  add_group "Helpers", "app/helpers"
  add_group "Channels", "app/channels"

  # 커버리지 80% 미만이면 빌드 실패
  minimum_coverage 80
  minimum_coverage_by_file 60

  # 커버리지 리포트 형식
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::SimpleFormatter,
    SimpleCov::Formatter::CoberturaFormatter
  ])

  # 캐시 설정 (병렬 테스트 지원)
  enable_coverage :branch
  primary_coverage :line

  track_files "{app,lib}/**/*.rb"
end
