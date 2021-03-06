module Gsa18f
  class ProcurementsController < UseCaseController
    protected

    def model_class
      Gsa18f::Procurement
    end

    def permitted_params
      fields = Gsa18f::Procurement.relevant_fields(
        params[:gsa18f_procurement][:recurring])
      params.require(:gsa18f_procurement).permit(:name, *fields)
    end
  end
end
