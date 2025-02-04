class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin
  before_action :set_user, only: [ :show, :edit, :update, :destroy ]

  def index
    @users = User.where(department: current_user.department)
  end

  def show
  end

  def new
    @user = User.new(department: current_user.department)
  end

  def edit
  end

  def create
    @user = User.new(user_params)
    @user.department = current_user.department
    @user.force_password_change = true

    # Gera uma senha temporária aleatória
    temporary_password = SecureRandom.hex(8)
    @user.password = temporary_password
    @user.password_confirmation = temporary_password

    if @user.save
      flash[:notice] = "Usuário criado com sucesso."
      flash[:passwords] = [ "#{@user.name} (#{@user.email}): #{temporary_password}" ]
      redirect_to users_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @user.update(user_params)
      redirect_to users_path, notice: "Usuário atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @user == current_user
      redirect_to users_path, alert: "Você não pode excluir seu próprio usuário."
    else
      @user.destroy
      redirect_to users_path, notice: "Usuário excluído com sucesso."
    end
  end

  private

  def set_user
    @user = User.where(department: current_user.department).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to users_path, alert: "Usuário não encontrado ou você não tem permissão para acessá-lo."
  end

  def user_params
    params.require(:user).permit(:name, :email, :registration_number, :role)
  end

  def ensure_admin
    unless current_user.admin?
      redirect_to root_path, alert: "Acesso não autorizado."
    end
  end
end
