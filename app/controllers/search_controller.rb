class SearchController < ApplicationController
  before_action :authenticate_user!, only: [:users]

  # {
  #     "query": {
  #         "filtered": {
  #             "query": {
  #                 "simple_query_string": {
  #                     "query": "appium",
  #                     "default_operator": "AND",
  #                     "minimum_should_match": "70%",
  #                     "fields": [
  #                         "title",
  #                         "body",
  #                         "name",
  #                         "login"
  #                     ]
  #                 }
  #             },
  #             "filter": {
  #                 "bool": {
  #                     "must_not": {
  #                         "term": {
  #                             "draft": true
  #                         }
  #                     }
  #                 }
  #             }
  #         }
  #     }
  # }

  def index
    params[:q] ||= ""

    search_modules = [Topic, User]
    search_modules << Page if Setting.has_module?(:wiki)
    if params[:excellent].present? and params[:excellent] == "1"
      search_params = {
          query: {
              filtered: {
                  query: {
                      simple_query_string: {
                          query: params[:q],
                          default_operator: "AND",
                          minimum_should_match: "70%",
                          fields: %w(title body name login)
                      }
                  },
                  filter: {
                      bool: {
                          must_not: {
                              term: {
                                  private_org: true
                              }
                          },
                          must: [
                            { match: { draft: false } },
                            { match: { excellent: 1 } }
                        ]
                      }
                  }
              }
          },
          highlight: {
              pre_tags: ["[h]"],
              post_tags: ["[/h]"],
              fields: {title: {}, body: {}, name: {}, login: {}}
          }
      }
    else
      search_params = {
          query: {
              filtered: {
                  query: {
                      simple_query_string: {
                          query: params[:q],
                          default_operator: "AND",
                          minimum_should_match: "70%",
                          fields: %w(title body name login)
                      }
                  },
                  filter: {
                      bool: {
                          must: {
                              term: {
                                  draft: false
                              }
                          },
                          must_not: {
                              term: {
                                  private_org: true
                              }
                          }
                      }
                  }
              }
          },
          highlight: {
              pre_tags: ["[h]"],
              post_tags: ["[/h]"],
              fields: {title: {}, body: {}, name: {}, login: {}}
          }
      }
    end

    @result = Elasticsearch::Model.search(search_params, search_modules).page(params[:page])
  end

  def users
    @result = User.search(params[:q], user: current_user, limit: params[:limit] || 10)
    render json: @result.collect {|u| {login: u.login, name: u.name, avatar_url: u.large_avatar_url}}
  end
end
