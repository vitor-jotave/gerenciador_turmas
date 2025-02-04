class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin
  before_action :set_user, only: [ :show, :edit, :update, :destroy, :regenerate_password, :manage_classes, :update_classes ]

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

  def regenerate_password
    if @user == current_user
      redirect_to edit_user_path(@user), alert: "Você não pode redefinir sua própria senha por aqui."
      return
    end

    # Gera uma nova senha temporária
    temporary_password = SecureRandom.hex(8)
    @user.password = temporary_password
    @user.password_confirmation = temporary_password
    @user.force_password_change = true

    if @user.save
      flash[:notice] = "Senha temporária gerada com sucesso."
      flash[:passwords] = [ "#{@user.name} (#{@user.email}): #{temporary_password}" ]
      redirect_to edit_user_path(@user)
    else
      redirect_to edit_user_path(@user), alert: "Não foi possível gerar uma nova senha."
    end
  end

  def manage_classes
    # Carrega todas as turmas do departamento
    @available_classes = SchoolClass.joins(subject: :department)
                                  .where(departments: { id: current_user.department_id })
                                  .order("subjects.name ASC, school_classes.semester DESC")
                                  .includes(:subject)

    # Se for professor, carrega as turmas que ele leciona
    if @user.teacher?
      @enrolled_classes = @user.teaching_classes
    else
      # Se for aluno, carrega as turmas em que está matriculado
      @enrolled_classes = @user.school_classes
    end
  end

  def update_classes
    selected_class_ids = params[:school_class_ids]&.map(&:to_i) || []

    # Remove todas as matrículas existentes
    if @user.teacher?
      @user.teachings.destroy_all
      # Cria novas matrículas como professor
      selected_class_ids.each do |class_id|
        @user.teachings.create(school_class_id: class_id)
      end
    else
      @user.enrollments.where(teacher_id: nil).destroy_all
      # Cria novas matrículas como aluno
      selected_class_ids.each do |class_id|
        @user.enrollments.create(school_class_id: class_id)
      end
    end

    redirect_to users_path, notice: "Turmas atualizadas com sucesso."
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
