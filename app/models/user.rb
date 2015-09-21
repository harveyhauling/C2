class User < ActiveRecord::Base
  has_paper_trail

  validates :client_slug, inclusion: {
    in: ->(_) { Proposal.client_slugs },
    allow_blank: true
  }
  validates :email_address, presence: true, uniqueness: true
  validates_email_format_of :email_address

  has_many :approvals
  has_many :observations
  has_many :comments

  # we do not use rolify gem (e.g.) but declare relationship like any other.
  has_many :user_roles
  has_many :roles, through: :user_roles

  # TODO rename to _delegations, and add relations for the Users
  has_many :outgoing_delegates, class_name: 'ApprovalDelegate', foreign_key: 'assigner_id'
  has_many :incoming_delegates, class_name: 'ApprovalDelegate', foreign_key: 'assignee_id'

  # this is for user_roles specifically, not proposals or any other objects for which
  # this user might have roles.
  # rubocop:disable Style/PredicateName
  def has_role?(name_or_role)
    if name_or_role.is_a?(Role)
      self.roles.include?(name_or_role)
    else
      self.roles.exists?(name: name_or_role)
    end
  end
  # rubocop:enable Style/PredicateName

  def add_role(name_or_role)
    if name_or_role.is_a?(Role)
      role = name_or_role
    else
      role = Role.find_or_create_by!(name: name_or_role)
    end
    self.user_roles.find_or_create_by!(role: role)
  end

  def self.with_role(name_or_role)
    if name_or_role.is_a?(Role)
      name_or_role.users
    else
      User.joins(:roles).where(roles: { name: name_or_role })
    end
  end

  def self.sql_for_role_slug(role, slug)
    self.with_role(role).select(:id).where(client_slug: slug).to_sql
  end

  def full_name
    if first_name && last_name
      "#{first_name} #{last_name}"
    else
      email_address
    end
  end

  def requested_proposals
    Proposal.where(requester_id: self.id)
  end

  def last_requested_proposal
    self.requested_proposals.order('created_at DESC').first
  end

  def add_delegate(other)
    self.outgoing_delegates.create!(assignee: other)
  end

  def delegates_to?(other)
    self.outgoing_delegates.exists?(assignee_id: other.id)
  end

  def client_admin?
    self.has_role?('client_admin')
  end

  def admin?
    self.has_role?('admin')
  end

  def self.for_email(email)
    User.find_or_create_by(email_address: email.strip.downcase)
  end

  def self.exists_with_role_slug?(role, slug)
    the_role = role.is_a?(Role) ? role : Role.find_by_name(role)
    return false unless the_role
    triple_exists = false
    the_role.users.each do |u|
      if u.client_slug == slug
        triple_exists = true
        break
      end
    end
    triple_exists
  end

  # find_or_create a User with particular email, role and slug
  # NOTE the triple is considered unique, so if a user with the role+slug
  # is found with another email address, no change is made and nil is returned.
  def self.with_email_role_slug!(email, role, slug)
    user = User.for_email(email)
    # if no change necessary, return early (idempotent)
    if user.client_slug == slug && user.has_role?(role)
      return user
    end

    # unique triple -- check if any other user with role+slug already exists
    return if self.exists_with_role_slug?(role, slug)

    user.client_slug = slug
    user.add_role(role)
    user.save!
    user
  end

  def self.from_oauth_hash(auth_hash)
    user_data = auth_hash.extra.raw_info.to_hash
    self.find_or_create_by(email_address: user_data['email'])
  end

  def role_on(proposal)
    RolePicker.new(self, proposal)
  end
end
