FactoryGirl.define do
  sequence(:public_id) { |n| "PUBLIC#{n}" }

  factory :proposal do
    public_id
    flow 'parallel'
    status 'pending'
    association :requester, factory: :user

    transient do
      client_slug { ENV['CLIENT_SLUG_DEFAULT'] || 'ncr' }
      delegate nil
      approver_user nil
    end

    trait :with_approver do
      after :create do |proposal, evaluator|
        user = evaluator.approver_user || create(:user, client_slug: evaluator.client_slug)
        proposal.add_initial_steps([Steps::Approval.new(user: user)])
      end
    end

    trait :with_serial_approvers do
      flow 'linear'
      after :create do |proposal, evaluator|
        ind = 2.times.map{ Steps::Approval.new(user: create(:user, client_slug: evaluator.client_slug)) }
        proposal.add_initial_steps(ind)
      end
    end

    trait :with_parallel_approvers do
      flow 'parallel'
      after :create do |proposal, evaluator|
        ind = 2.times.map{ Steps::Approval.new(user: create(:user, client_slug: evaluator.client_slug)) }
        proposal.root_step = Steps::Parallel.new(child_approvals: ind)
      end
    end

    trait :with_observer do
      after :create do |proposal, evaluator|
        observer = create(:user, client_slug: evaluator.client_slug)
        proposal.add_observer(observer.email_address)
      end
    end

    trait :with_observers do
      after :create do |proposal, evaluator|
        2.times do
          observer = create(:user, client_slug: evaluator.client_slug)
          proposal.add_observer(observer.email_address)
        end
      end
    end

    after(:create) do |proposal, evaluator|
      if evaluator.delegate
        user = evaluator.approver_user || create(:user, client_slug: evaluator.client_slug)
        proposal.add_initial_steps([Steps::Approval.new(user: user)])
        user.add_delegate(evaluator.delegate)
      end
    end
  end
end
